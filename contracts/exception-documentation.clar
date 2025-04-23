;; exception-documentation.clar
;; Contract to record delivery problems

(define-data-var admin principal tx-sender)

;; Exception types
(define-constant EXCEPTION-DAMAGE u1)
(define-constant EXCEPTION-DELAY u2)
(define-constant EXCEPTION-MISSING-ITEMS u3)
(define-constant EXCEPTION-WRONG-DELIVERY u4)
(define-constant EXCEPTION-OTHER u5)

;; Map to store exceptions
(define-map exceptions { shipment-id: uint, exception-id: uint }
  {
    reporter: principal,
    exception-type: uint,
    description: (string-utf8 500),
    evidence-hash: (buff 32),
    reported-at: uint,
    status: uint
  }
)

;; Counter for exception IDs per shipment
(define-map shipment-exception-count uint uint)

;; Exception status enum
(define-constant STATUS-REPORTED u1)
(define-constant STATUS-UNDER-REVIEW u2)
(define-constant STATUS-RESOLVED u3)
(define-constant STATUS-REJECTED u4)

;; Public function to report an exception
(define-public (report-exception
    (shipment-id uint)
    (exception-type uint)
    (description (string-utf8 500))
    (evidence-hash (buff 32)))
  (let ((exception-id (default-to u0 (map-get? shipment-exception-count shipment-id))))

    ;; Verify exception type is valid
    (asserts! (and (>= exception-type EXCEPTION-DAMAGE)
                  (<= exception-type EXCEPTION-OTHER))
              (err u400))

    ;; Set exception count for this shipment
    (map-set shipment-exception-count shipment-id (+ exception-id u1))

    ;; Record the exception
    (map-set exceptions { shipment-id: shipment-id, exception-id: exception-id }
      {
        reporter: tx-sender,
        exception-type: exception-type,
        description: description,
        evidence-hash: evidence-hash,
        reported-at: block-height,
        status: STATUS-REPORTED
      })

    (ok exception-id)
  )
)

;; Function to update exception status
(define-public (update-exception-status
    (shipment-id uint)
    (exception-id uint)
    (new-status uint))
  (match (map-get? exceptions { shipment-id: shipment-id, exception-id: exception-id })
    exception-data
      (begin
        ;; Verify status is valid
        (asserts! (and (>= new-status STATUS-REPORTED)
                      (<= new-status STATUS-REJECTED))
                  (err u400))

        ;; Update exception status
        (map-set exceptions { shipment-id: shipment-id, exception-id: exception-id }
          (merge exception-data { status: new-status }))

        (ok true)
      )
    (err u404)
  )
)

;; Read-only function to get exception details
(define-read-only (get-exception (shipment-id uint) (exception-id uint))
  (map-get? exceptions { shipment-id: shipment-id, exception-id: exception-id })
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
