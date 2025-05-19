;; Risk Assessment Contract
;; Calculates appropriate interest rates

(define-data-var admin principal tx-sender)

;; Constants for interest rate calculation
(define-data-var base-rate uint u500) ;; 5.00%
(define-data-var max-rate uint u3000) ;; 30.00%
(define-data-var credit-score-factor uint u5) ;; How much credit score affects rate
(define-data-var collateral-factor uint u10) ;; How much collateral affects rate

;; Map to store calculated interest rates
(define-map loan-interest-rates uint uint) ;; loan-id -> interest rate (percentage * 100)

;; Calculate interest rate based on borrower's credit score and collateral
(define-public (calculate-interest-rate (loan-id uint) (credit-score uint) (loan-amount-usd uint) (collateral-value-usd uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can calculate

    (let (
      (ltv-ratio (/ (* loan-amount-usd u10000) collateral-value-usd))
      (credit-adjustment (/ (* credit-score (var-get credit-score-factor)) u100))
      (collateral-adjustment (/ (* ltv-ratio (var-get collateral-factor)) u100))
      (final-rate (+ (- (var-get base-rate) credit-adjustment) collateral-adjustment))
    )
      ;; Ensure rate is within bounds
      (if (> final-rate (var-get max-rate))
        (map-set loan-interest-rates loan-id (var-get max-rate))
        (map-set loan-interest-rates loan-id final-rate)
      )

      (ok (default-to u0 (map-get? loan-interest-rates loan-id)))
    )
  )
)

;; Get interest rate for a loan
(define-read-only (get-interest-rate (loan-id uint))
  (default-to u0 (map-get? loan-interest-rates loan-id))
)

;; Update base interest rate (admin only)
(define-public (update-base-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can update
    (asserts! (<= new-rate (var-get max-rate)) (err u8)) ;; Base rate must be <= max rate

    (var-set base-rate new-rate)
    (ok true)
  )
)

;; Calculate maximum loan amount based on credit score and collateral
(define-read-only (calculate-max-loan-amount (credit-score uint) (collateral-value-usd uint))
  (let (
    (credit-factor (/ credit-score u1000)) ;; 0.5 to 1.0 based on credit score
    (max-ltv u7000) ;; 70% maximum loan-to-value ratio
  )
    (/ (* collateral-value-usd max-ltv credit-factor) u10000)
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
