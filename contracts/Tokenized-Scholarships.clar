(define-non-fungible-token scholarship-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-not-found (err u104))
(define-constant err-already-issued (err u105))
(define-constant err-unauthorized (err u106))
(define-constant err-invalid-amount (err u107))
(define-constant err-expired (err u108))
(define-constant err-already-used (err u109))
(define-constant err-transfer-blocked (err u110))

(define-data-var last-token-id uint u0)
(define-data-var total-scholarships uint u0)
(define-data-var active-scholarships uint u0)
(define-data-var used-scholarships uint u0)
(define-data-var expired-scholarships uint u0)

(define-map scholarship-details
    uint
    {
        recipient: principal,
        institution: (string-ascii 100),
        amount: uint,
        field-of-study: (string-ascii 100),
        issue-date: uint,
        expiry-date: uint,
        issuer: principal,
        is-used: bool,
        scholarship-id: (string-ascii 50),
    }
)

(define-map authorized-issuers
    principal
    bool
)

(define-map institution-scholarships
    (string-ascii 100)
    (list 200 uint)
)

(define-map recipient-scholarships
    principal
    (list 50 uint)
)

(define-map scholarship-usage
    uint
    {
        used-at: uint,
        used-by: principal,
        transaction-id: (string-ascii 100),
    }
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? scholarship-nft token-id))
)

(define-read-only (get-scholarship-details (token-id uint))
    (map-get? scholarship-details token-id)
)

(define-read-only (get-total-scholarships)
    (var-get total-scholarships)
)

(define-read-only (get-active-scholarships-count)
    (var-get active-scholarships)
)

(define-read-only (get-used-scholarships-count)
    (var-get used-scholarships)
)

(define-read-only (get-expired-scholarships-count)
    (var-get expired-scholarships)
)

(define-read-only (is-authorized-issuer (issuer principal))
    (default-to false (map-get? authorized-issuers issuer))
)

(define-read-only (get-institution-scholarships (institution (string-ascii 100)))
    (default-to (list) (map-get? institution-scholarships institution))
)

(define-read-only (get-recipient-scholarships (recipient principal))
    (default-to (list) (map-get? recipient-scholarships recipient))
)

(define-read-only (get-scholarship-usage (token-id uint))
    (map-get? scholarship-usage token-id)
)

(define-read-only (is-scholarship-valid (token-id uint))
    (match (map-get? scholarship-details token-id)
        scholarship-info (let (
                (current-block burn-block-height)
                (expiry-date (get expiry-date scholarship-info))
                (is-used (get is-used scholarship-info))
            )
            (and
                (< current-block expiry-date)
                (not is-used)
            )
        )
        false
    )
)

(define-read-only (get-scholarship-status (token-id uint))
    (match (map-get? scholarship-details token-id)
        scholarship-info (let (
                (current-block burn-block-height)
                (expiry-date (get expiry-date scholarship-info))
                (is-used (get is-used scholarship-info))
            )
            (if is-used
                "used"
                (if (< current-block expiry-date)
                    "active"
                    "expired"
                )
            )
        )
        "not-found"
    )
)

(define-read-only (get-scholarship-count-by-institution (institution (string-ascii 100)))
    (len (get-institution-scholarships institution))
)

(define-read-only (get-scholarship-count-by-recipient (recipient principal))
    (len (get-recipient-scholarships recipient))
)

(define-public (add-authorized-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set authorized-issuers issuer true))
    )
)

(define-public (remove-authorized-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-delete authorized-issuers issuer))
    )
)

(define-public (issue-scholarship
        (recipient principal)
        (institution (string-ascii 100))
        (amount uint)
        (field-of-study (string-ascii 100))
        (expiry-blocks uint)
        (scholarship-id (string-ascii 50))
    )
    (let (
            (token-id (+ (var-get last-token-id) u1))
            (current-block burn-block-height)
            (expiry-date (+ current-block expiry-blocks))
        )
        (asserts! (is-authorized-issuer tx-sender) err-unauthorized)
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (> expiry-blocks u0) err-invalid-amount)

        (try! (nft-mint? scholarship-nft token-id recipient))

        (map-set scholarship-details token-id {
            recipient: recipient,
            institution: institution,
            amount: amount,
            field-of-study: field-of-study,
            issue-date: current-block,
            expiry-date: expiry-date,
            issuer: tx-sender,
            is-used: false,
            scholarship-id: scholarship-id,
        })

        (map-set institution-scholarships institution
            (unwrap-panic (as-max-len?
                (append (get-institution-scholarships institution) token-id)
                u200
            ))
        )

        (map-set recipient-scholarships recipient
            (unwrap-panic (as-max-len? (append (get-recipient-scholarships recipient) token-id)
                u50
            ))
        )

        (var-set last-token-id token-id)
        (var-set total-scholarships (+ (var-get total-scholarships) u1))
        (var-set active-scholarships (+ (var-get active-scholarships) u1))

        (ok token-id)
    )
)

(define-public (use-scholarship
        (token-id uint)
        (transaction-id (string-ascii 100))
    )
    (let (
            (scholarship-info (unwrap! (map-get? scholarship-details token-id) err-not-found))
            (token-owner (unwrap! (nft-get-owner? scholarship-nft token-id) err-not-found))
            (current-block burn-block-height)
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (asserts! (not (get is-used scholarship-info)) err-already-used)
        (asserts! (< current-block (get expiry-date scholarship-info))
            err-expired
        )

        (map-set scholarship-details token-id
            (merge scholarship-info { is-used: true })
        )

        (map-set scholarship-usage token-id {
            used-at: current-block,
            used-by: tx-sender,
            transaction-id: transaction-id,
        })

        (var-set active-scholarships (- (var-get active-scholarships) u1))
        (var-set used-scholarships (+ (var-get used-scholarships) u1))

        (ok true)
    )
)

(define-public (extend-scholarship-expiry
        (token-id uint)
        (additional-blocks uint)
    )
    (let (
            (scholarship-info (unwrap! (map-get? scholarship-details token-id) err-not-found))
            (issuer (get issuer scholarship-info))
        )
        (asserts! (is-eq tx-sender issuer) err-unauthorized)
        (asserts! (> additional-blocks u0) err-invalid-amount)

        (map-set scholarship-details token-id
            (merge scholarship-info { expiry-date: (+ (get expiry-date scholarship-info) additional-blocks) })
        )

        (ok true)
    )
)

(define-public (revoke-scholarship (token-id uint))
    (let (
            (scholarship-info (unwrap! (map-get? scholarship-details token-id) err-not-found))
            (issuer (get issuer scholarship-info))
            (current-block burn-block-height)
        )
        (asserts! (is-eq tx-sender issuer) err-unauthorized)
        (asserts! (not (get is-used scholarship-info)) err-already-used)

        (map-set scholarship-details token-id
            (merge scholarship-info { expiry-date: current-block })
        )

        (var-set active-scholarships (- (var-get active-scholarships) u1))
        (var-set expired-scholarships (+ (var-get expired-scholarships) u1))

        (ok true)
    )
)

(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! false err-transfer-blocked)
        (ok false)
    )
)

(define-public (update-expired-status (token-id uint))
    (let (
            (scholarship-info (unwrap! (map-get? scholarship-details token-id) err-not-found))
            (current-block burn-block-height)
            (expiry-date (get expiry-date scholarship-info))
            (is-used (get is-used scholarship-info))
        )
        (asserts! (>= current-block expiry-date) err-invalid-amount)
        (asserts! (not is-used) err-already-used)

        (var-set active-scholarships (- (var-get active-scholarships) u1))
        (var-set expired-scholarships (+ (var-get expired-scholarships) u1))

        (ok true)
    )
)

(define-read-only (get-scholarship-stats)
    {
        total: (var-get total-scholarships),
        active: (var-get active-scholarships),
        used: (var-get used-scholarships),
        expired: (var-get expired-scholarships),
    }
)

(define-read-only (verify-scholarship-authenticity (token-id uint))
    (match (map-get? scholarship-details token-id)
        scholarship-info (let (
                (issuer (get issuer scholarship-info))
                (issue-date (get issue-date scholarship-info))
            )
            {
                is-authentic: (is-authorized-issuer issuer),
                issuer: issuer,
                issue-date: issue-date,
                scholarship-id: (get scholarship-id scholarship-info),
            }
        )
        {
            is-authentic: false,
            issuer: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM,
            issue-date: u0,
            scholarship-id: "",
        }
    )
)

(define-read-only (get-scholarship-value (token-id uint))
    (match (map-get? scholarship-details token-id)
        scholarship-info (get amount scholarship-info)
        u0
    )
)

(define-read-only (get-scholarship-institution (token-id uint))
    (match (map-get? scholarship-details token-id)
        scholarship-info (get institution scholarship-info)
        ""
    )
)

(define-read-only (get-scholarship-field (token-id uint))
    (match (map-get? scholarship-details token-id)
        scholarship-info (get field-of-study scholarship-info)
        ""
    )
)

(begin
    (map-set authorized-issuers contract-owner true)
)
