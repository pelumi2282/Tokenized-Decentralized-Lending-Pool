;; Repayment Tracking Contract
;; Manages loan servicing and collections

(define-data-var admin principal tx-sender)

;; Map to store loan details
(define-map loans
  uint
  {
    borrower: principal,
    amount: uint,
    interest-rate: uint,
    term-length: uint,
    start-block: uint,
    end-block: uint,
    total-repaid: uint,
    status: (string-ascii 20)
  }
)

;; Map to store repayment schedule
(define-map repayment-schedule
  { loan-id: uint, payment-number: uint }
  {
    amount-due: uint,
    due-block: uint,
    paid: bool,
    paid-block: uint
  }
)

;; Counter for loan IDs
(define-data-var next-loan-id uint u1)

;; Create a new loan (simplified without actual token transfer)
(define-public (create-loan (borrower principal) (amount uint) (term-length uint) (interest-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can create loans

    (let (
      (loan-id (var-get next-loan-id))
      (start-block block-height)
      (end-block (+ block-height term-length))
    )
      ;; Record loan details
      (map-set loans
        loan-id
        {
          borrower: borrower,
          amount: amount,
          interest-rate: interest-rate,
          term-length: term-length,
          start-block: start-block,
          end-block: end-block,
          total-repaid: u0,
          status: "active"
        }
      )

      ;; Create repayment schedule (simplified - equal payments)
      (let (
        (payment-count u6) ;; 6 payments
        (payment-interval (/ term-length payment-count))
        (total-with-interest (+ amount (/ (* amount interest-rate) u10000)))
        (payment-amount (/ total-with-interest payment-count))
      )
        (var-set next-loan-id (+ loan-id u1))

        ;; Create payment schedule entries
        (create-payment-schedule loan-id payment-count payment-interval payment-amount start-block)

        (ok loan-id)
      )
    )
  )
)

;; Helper function to create payment schedule
(define-private (create-payment-schedule (loan-id uint) (payment-count uint) (payment-interval uint) (payment-amount uint) (start-block uint))
  (begin
    (let (
      (counter uint u1)
    )
      (asserts! (<= counter payment-count) (err u0))

      (map-set repayment-schedule
        { loan-id: loan-id, payment-number: counter }
        {
          amount-due: payment-amount,
          due-block: (+ start-block (* counter payment-interval)),
          paid: false,
          paid-block: u0
        }
      )

      (if (< counter payment-count)
        (create-payment-schedule loan-id payment-count payment-interval payment-amount start-block)
        true
      )
    )
  )
)

;; Record a loan repayment (simplified without actual token transfer)
(define-public (record-repayment (loan-id uint) (payment-number uint) (borrower principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can record

    (let (
      (loan (default-to
        {
          borrower: borrower,
          amount: u0,
          interest-rate: u0,
          term-length: u0,
          start-block: u0,
          end-block: u0,
          total-repaid: u0,
          status: "unknown"
        }
        (map-get? loans loan-id)))
      (payment (default-to
        {
          amount-due: u0,
          due-block: u0,
          paid: false,
          paid-block: u0
        }
        (map-get? repayment-schedule { loan-id: loan-id, payment-number: payment-number })))
    )
      (asserts! (is-eq borrower (get borrower loan)) (err u9)) ;; Not the borrower
      (asserts! (not (get paid payment)) (err u10)) ;; Already paid
      (asserts! (is-eq (get status loan) "active") (err u11)) ;; Loan not active

      ;; Update payment status
      (map-set repayment-schedule
        { loan-id: loan-id, payment-number: payment-number }
        (merge payment
          {
            paid: true,
            paid-block: block-height
          }
        )
      )

      ;; Update loan total repaid
      (map-set loans
        loan-id
        (merge loan
          {
            total-repaid: (+ (get total-repaid loan) (get amount-due payment))
          }
        )
      )

      ;; Check if loan is fully repaid
      (if (is-loan-fully-repaid loan-id)
        (begin
          (map-set loans
            loan-id
            (merge loan { status: "repaid" })
          )
        )
        true
      )

      (ok true)
    )
  )
)

;; Check if loan is fully repaid
(define-read-only (is-loan-fully-repaid (loan-id uint))
  (let (
    (loan (default-to
      {
        borrower: tx-sender,
        amount: u0,
        interest-rate: u0,
        term-length: u0,
        start-block: u0,
        end-block: u0,
        total-repaid: u0,
        status: "unknown"
      }
      (map-get? loans loan-id)))
    (total-due (+ (get amount loan) (/ (* (get amount loan) (get interest-rate loan)) u10000)))
  )
    (>= (get total-repaid loan) total-due)
  )
)

;; Check for late payments and update loan status
(define-public (check-loan-status (loan-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can check

    (let (
      (loan (default-to
        {
          borrower: tx-sender,
          amount: u0,
          interest-rate: u0,
          term-length: u0,
          start-block: u0,
          end-block: u0,
          total-repaid: u0,
          status: "unknown"
        }
        (map-get? loans loan-id)))
    )
      (if (and (is-eq (get status loan) "active") (> block-height (get end-block loan)))
        (if (is-loan-fully-repaid loan-id)
          (begin
            (map-set loans loan-id (merge loan { status: "repaid" }))
          )
          (begin
            (map-set loans loan-id (merge loan { status: "defaulted" }))
          )
        )
        true
      )

      (ok true)
    )
  )
)

;; Get loan details
(define-read-only (get-loan-details (loan-id uint))
  (default-to
    {
      borrower: tx-sender,
      amount: u0,
      interest-rate: u0,
      term-length: u0,
      start-block: u0,
      end-block: u0,
      total-repaid: u0,
      status: "unknown"
    }
    (map-get? loans loan-id)
  )
)

;; Get payment details
(define-read-only (get-payment-details (loan-id uint) (payment-number uint))
  (default-to
    {
      amount-due: u0,
      due-block: u0,
      paid: false,
      paid-block: u0
    }
    (map-get? repayment-schedule { loan-id: loan-id, payment-number: payment-number })
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
