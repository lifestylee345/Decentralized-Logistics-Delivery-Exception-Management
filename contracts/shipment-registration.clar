;; shipment-registration.clar
;; Contract to record delivery requirements

(define-data-var admin principal tx-sender)

;; Shipment status enum
(define-constant STATUS-REGISTERED u1)
(define-constant STATUS-IN-TRANSIT u2)
(define-constant STATUS-DELIVERED u3)
(define-constant STATUS-EXCEPTION u4)
(define-constant STATUS-RESOLVED u5)

;; Map to store shipments
(define-map shipments uint
  {
    shipper: principal,
    carrier: principal,
    recipient: (string-utf8 100),
    origin: (string-utf8 100),
    destination: (string-utf8 100),
    expected-delivery: uint,
    requirements: (string-utf8 200),
    status: uint,
    registered-at: uint
  }
)

;; Counter for shipment IDs
(define-data-var next-shipment-id uint u1)

;; Public function to register a new shipment
(define-public (register-shipment
    (carrier principal)
    (recipient (string-utf8 100))
    (origin (string-utf8 100))
    (destination (string-utf8 100))
    (expected-delivery uint)
    (requirements (string-utf8 200)))
  (let ((shipment-id (var-get next-shipment-id)))
    (map-set shipments shipment-id {
      shipper: tx-sender,
      carrier: carrier,
      recipient: recipient,
      origin: origin,
      destination: destination,
      expected-delivery: expected-delivery,
      requirements: requirements,
      status: STATUS-REGISTERED,
      registered-at: block-height
    })

    (var-set next-shipment-id (+ shipment-id u1))
    (ok shipment-id)
  )
)

;; Function to update shipment status
(define-public (update-shipment-status (shipment-id uint) (new-status uint))
  (match (map-get? shipments shipment-id)
    shipment-data
      (begin
        (asserts! (or (is-eq tx-sender (get carrier shipment-data))
                      (is-eq tx-sender (get shipper shipment-data))
                      (is-eq tx-sender (var-get admin)))
                  (err u403))
        (asserts! (and (>= new-status STATUS-REGISTERED)
                       (<= new-status STATUS-RESOLVED))
                  (err u400))

        (map-set shipments shipment-id
          (merge shipment-data { status: new-status }))
        (ok true)
      )
    (err u404)
  )
)

;; Read-only function to get shipment details
(define-read-only (get-shipment (shipment-id uint))
  (map-get? shipments shipment-id)
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (var-set admin new-admin)
    (ok true)
  )
)
