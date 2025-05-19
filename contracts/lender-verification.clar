;; Lender Verification Contract
;; Validates funding participants

(define-data-var min-deposit uint u1000)
(define-data-var admin principal tx-sender)

;; Map to store verified lenders
(define-map verified-lenders principal bool)

;; Map to store lender details
(define-map lender-details
  principal
  {
    total-deposited: uint,
    active: bool,
    verification-date: uint
  }
)

;; Register as a lender
(define-public (register-lender)
  (begin
    (asserts! (not (default-to false (map-get? verified-lenders tx-sender))) (err u1)) ;; Already registered
    (map-set verified-lenders tx-sender false)
    (map-set lender-details
      tx-sender
      {
        total-deposited: u0,
        active: false,
        verification-date: u0
      }
    )
    (ok true)
  )
)

;; Verify a lender (admin only)
(define-public (verify-lender (lender principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can verify
    (asserts! (default-to false (map-get? verified-lenders lender)) (err u404)) ;; Lender not found
    (map-set verified-lenders lender true)
    (map-set lender-details
      lender
      (merge (default-to
        {
          total-deposited: u0,
          active: false,
          verification-date: u0
        }
        (map-get? lender-details lender)
      )
      {
        active: true,
        verification-date: block-height
      }
    ))
    (ok true)
  )
)

;; Check if lender is verified
(define-read-only (is-verified-lender (lender principal))
  (default-to false (map-get? verified-lenders lender))
)

;; Record a deposit (simplified without actual token transfer)
(define-public (record-deposit (lender principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can record
    (asserts! (is-verified-lender lender) (err u401)) ;; Not verified
    (asserts! (>= amount (var-get min-deposit)) (err u2)) ;; Below minimum

    ;; Update lender details
    (map-set lender-details
      lender
      (merge (default-to
        {
          total-deposited: u0,
          active: false,
          verification-date: u0
        }
        (map-get? lender-details lender)
      )
      {
        total-deposited: (+ (get total-deposited (default-to
          {
            total-deposited: u0,
            active: false,
            verification-date: u0
          }
          (map-get? lender-details lender))) amount)
      }
    ))

    (ok true)
  )
)

;; Set a new admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can change admin
    (var-set admin new-admin)
    (ok true)
  )
)

;; Get admin
(define-read-only (get-admin)
  (var-get admin)
)
