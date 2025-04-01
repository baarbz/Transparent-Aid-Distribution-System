;; Recipient Verification Contract
;; This contract validates the eligibility of aid beneficiaries

(define-data-var admin principal tx-sender)

;; Data structure for recipients
(define-map recipients
  { id: (string-utf8 36) }  ;; UUID as identifier
  {
    name: (string-utf8 100),
    location: (string-utf8 100),
    verified: bool,
    needs-assessment: (string-utf8 500),
    verification-date: uint,
    verifier: principal
  }
)

;; List of verified recipient IDs for easy lookup
(define-data-var verified-recipient-count uint u0)
(define-map verified-recipient-ids uint (string-utf8 36))

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Set a new admin
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err u403))
    (ok (var-set admin new-admin))
  )
)

;; Register a new recipient
(define-public (register-recipient
    (id (string-utf8 36))
    (name (string-utf8 100))
    (location (string-utf8 100))
    (needs-assessment (string-utf8 500))
  )
  (begin
    (asserts! (is-admin) (err u403))
    (asserts! (is-none (map-get? recipients {id: id})) (err u400))

    (map-set recipients
      {id: id}
      {
        name: name,
        location: location,
        verified: false,
        needs-assessment: needs-assessment,
        verification-date: u0,
        verifier: tx-sender
      }
    )
    (ok true)
  )
)

;; Verify a recipient
(define-public (verify-recipient (id (string-utf8 36)))
  (let (
    (recipient (unwrap! (map-get? recipients {id: id}) (err u404)))
    (current-count (var-get verified-recipient-count))
  )
    (asserts! (is-admin) (err u403))
    (asserts! (not (get verified recipient)) (err u400))

    (map-set recipients
      {id: id}
      (merge recipient {
        verified: true,
        verification-date: block-height,
        verifier: tx-sender
      })
    )

    ;; Add to verified list
    (map-set verified-recipient-ids current-count id)
    (var-set verified-recipient-count (+ current-count u1))

    (ok true)
  )
)

;; Revoke verification
(define-public (revoke-verification (id (string-utf8 36)))
  (let (
    (recipient (unwrap! (map-get? recipients {id: id}) (err u404)))
  )
    (asserts! (is-admin) (err u403))
    (asserts! (get verified recipient) (err u400))

    (map-set recipients
      {id: id}
      (merge recipient {
        verified: false
      })
    )

    ;; Note: We don't remove from the verified-recipient-ids map for simplicity
    ;; In a production system, we would need to handle this more carefully

    (ok true)
  )
)

;; Check if a recipient is verified
(define-read-only (is-recipient-verified (id (string-utf8 36)))
  (match (map-get? recipients {id: id})
    recipient (ok (get verified recipient))
    (err u404)
  )
)

;; Get recipient details
(define-read-only (get-recipient (id (string-utf8 36)))
  (map-get? recipients {id: id})
)

;; Get verified recipient count
(define-read-only (get-verified-count)
  (var-get verified-recipient-count)
)

;; Get verified recipient by index
(define-read-only (get-verified-recipient-by-index (index uint))
  (let (
    (id (map-get? verified-recipient-ids index))
  )
    (match id
      recipient-id (map-get? recipients {id: recipient-id})
      none
    )
  )
)
