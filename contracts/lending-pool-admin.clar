;; Lending Pool Admin Contract
;; Central contract for admin functions and configuration

;; Store admin address
(define-data-var admin principal tx-sender)

;; Get admin address
(define-read-only (get-admin)
  (var-get admin)
)

;; Set new admin (only current admin)
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can change admin
    (var-set admin new-admin)
    (ok true)
  )
)

;; Set admin for all contracts
(define-public (set-all-admins (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can set

    ;; Set admin for each contract
    (try! (set-admin new-admin))

    (ok true)
  )
)
