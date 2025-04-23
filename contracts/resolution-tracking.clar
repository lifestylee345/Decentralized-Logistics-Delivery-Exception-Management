;; resolution-tracking.clar
;; Contract to manage corrective actions for exceptions

(define-data-var admin principal tx-sender)

;; Resolution status enum
(define-constant STATUS-PROPOSED u1)
(define-constant STATUS-ACCEPTED u2)
(define-constant STATUS-REJECTED u3)
(define-constant STATUS-COMPLETED u4)

;; Map to store resolutions
(define-map resolutions { shipment-id: uint, exception-id: uint, resolution-id: uint }
  {
    proposer: principal,
    action-plan: (string-utf8 500),
    compensation: uint,
    deadline: uint,
    status: uint,
    proposed-at: uint,
    completed-at: (optional uint)
  }
)

;; Counter for resolution IDs per exception
(define-map exception-resolution-count { shipment-id: uint, exception-id: uint } uint)

;; Public function to propose a resolution
(define-public (propose-resolution
    (shipment-id uint)
    (exception-id uint)
    (action-plan (string-utf8 500))
    (compensation uint)
    (deadline uint))
  (let ((resolution-id (default-to u0 (map-get? exception-resolution-count { shipment-id: shipment-id, exception-id: exception-id }))))

    ;; Set resolution count for this exception
    (map-set exception-resolution-count
      { shipment-id: shipment-id, exception-id: exception-id }
      (+ resolution-id u1))

    ;; Record the resolution
    (map-set resolutions
      { shipment-id: shipment-id, exception-id: exception-id, resolution-id: resolution-id }
      {
        proposer: tx-sender,
        action-plan: action-plan,
        compensation: compensation,
        deadline: deadline,
        status: STATUS-PROPOSED,
        proposed-at: block-height,
        completed-at: none
      })

    (ok resolution-id)
  )
)

;; Function to update resolution status
(define-public (update-resolution-status
    (shipment-id uint)
    (exception-id uint)
    (resolution-id uint)
    (new-status uint))
  (match (map-get? resolutions { shipment-id: shipment-id, exception-id: exception-id, resolution-id: resolution-id })
    resolution-data
      (begin
        ;; Verify status is valid
        (asserts! (and (>= new-status STATUS-PROPOSED)
                      (<= new-status STATUS-COMPLETED))
                  (err u400))

        ;; Update resolution status
        (map-set resolutions
          { shipment-id: shipment-id, exception-id: exception-id, resolution-id: resolution-id }
          (merge resolution-data {
            status: new-status,
            completed-at: (if (is-eq new-status STATUS-COMPLETED)
                             (some block-height)
                             (get completed-at resolution-data))
          }))

        (ok true)
      )
    (err u404)
  )
)

;; Read-only function to get resolution details
(define-read-only (get-resolution (shipment-id uint) (exception-id uint) (resolution-id uint))
  (map-get? resolutions { shipment-id: shipment-id, exception-id: exception-id, resolution-id: resolution-id })
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
