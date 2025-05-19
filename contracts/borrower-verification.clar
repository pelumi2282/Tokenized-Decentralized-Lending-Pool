;; Borrower Verification Contract
;; Validates loan recipients

(define-data-var admin principal tx-sender)

;; Map to store verified borrowers
(define-map verified-borrowers principal bool)

;; Map to store borrower details
(define-map borrower-details
  principal
  {
    credit-score: uint,
    active: bool,
    verification-date: uint,
    loans-taken: uint,
    loans-repaid: uint
  }
)

;; Register as a borrower
(define-public (register-borrower)
  (begin
    (asserts! (not (default-to false (map-get? verified-borrowers tx-sender))) (err u1)) ;; Already registered
    (map-set verified-borrowers tx-sender false)
    (map-set borrower-details
      tx-sender
      {
        credit-score: u500, ;; Default credit score
        active: false,
        verification-date: u0,
        loans-taken: u0,
        loans-repaid: u0
      }
    )
    (ok true)
  )
)

;; Verify a borrower (admin only)
(define-public (verify-borrower (borrower principal) (credit-score uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can verify
    (asserts! (default-to false (map-get? verified-borrowers borrower)) (err u404)) ;; Borrower not found
    (map-set verified-borrowers borrower true)
    (map-set borrower-details
      borrower
      (merge (default-to
        {
          credit-score: u500,
          active: false,
          verification-date: u0,
          loans-taken: u0,
          loans-repaid: u0
        }
        (map-get? borrower-details borrower)
      )
      {
        credit-score: credit-score,
        active: true,
        verification-date: block-height
      }
    ))
    (ok true)
  )
)

;; Check if borrower is verified
(define-read-only (is-verified-borrower (borrower principal))
  (default-to false (map-get? verified-borrowers borrower))
)

;; Get borrower credit score
(define-read-only (get-credit-score (borrower principal))
  (get credit-score (default-to
    {
      credit-score: u0,
      active: false,
      verification-date: u0,
      loans-taken: u0,
      loans-repaid: u0
    }
    (map-get? borrower-details borrower)
  ))
)

;; Update borrower stats when loan is taken
(define-public (record-loan-taken (borrower principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can update
    (asserts! (is-verified-borrower borrower) (err u401)) ;; Not verified

    (map-set borrower-details
      borrower
      (merge (default-to
        {
          credit-score: u500,
          active: false,
          verification-date: u0,
          loans-taken: u0,
          loans-repaid: u0
        }
        (map-get? borrower-details borrower)
      )
      {
        loans-taken: (+ (get loans-taken (default-to
          {
            credit-score: u500,
            active: false,
            verification-date: u0,
            loans-taken: u0,
            loans-repaid: u0
          }
          (map-get? borrower-details borrower))) u1)
      }
    ))

    (ok true)
  )
)

;; Update borrower stats when loan is repaid
(define-public (record-loan-repaid (borrower principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can update
    (asserts! (is-verified-borrower borrower) (err u401)) ;; Not verified

    (map-set borrower-details
      borrower
      (merge (default-to
        {
          credit-score: u500,
          active: false,
          verification-date: u0,
          loans-taken: u0,
          loans-repaid: u0
        }
        (map-get? borrower-details borrower)
      )
      {
        loans-repaid: (+ (get loans-repaid (default-to
          {
            credit-score: u500,
            active: false,
            verification-date: u0,
            loans-taken: u0,
            loans-repaid: u0
          }
          (map-get? borrower-details borrower))) u1),
        credit-score: (+ (get credit-score (default-to
          {
            credit-score: u500,
            active: false,
            verification-date: u0,
            loans-taken: u0,
            loans-repaid: u0
          }
          (map-get? borrower-details borrower))) u50) ;; Increase credit score on repayment
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
