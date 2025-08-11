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
(define-constant err-pool-not-found (err u111))
(define-constant err-pool-inactive (err u112))
(define-constant err-insufficient-pool-funds (err u113))
(define-constant err-min-amount-not-met (err u114))

(define-data-var last-token-id uint u0)
(define-data-var total-scholarships uint u0)
(define-data-var active-scholarships uint u0)
(define-data-var used-scholarships uint u0)
(define-data-var expired-scholarships uint u0)
(define-data-var last-pool-id uint u0)

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

(define-map scholarship-pools
    uint
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 200),
        target-amount: uint,
        current-amount: uint,
        min-scholarship-amount: uint,
        institution: (string-ascii 100),
        field-of-study: (string-ascii 100),
        is-active: bool,
        created-at: uint,
        deadline: uint,
    }
)

(define-map pool-contributions
    {
        pool-id: uint,
        contributor: principal,
    }
    uint
)

(define-map pool-contributors
    uint
    (list 100 principal)
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

(define-read-only (get-pool-details (pool-id uint))
    (map-get? scholarship-pools pool-id)
)

(define-read-only (get-pool-contributors (pool-id uint))
    (default-to (list) (map-get? pool-contributors pool-id))
)

(define-read-only (get-user-contribution
        (pool-id uint)
        (contributor principal)
    )
    (default-to u0
        (map-get? pool-contributions {
            pool-id: pool-id,
            contributor: contributor,
        })
    )
)

(define-read-only (get-last-pool-id)
    (var-get last-pool-id)
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

(define-public (create-scholarship-pool
        (title (string-ascii 100))
        (description (string-ascii 200))
        (target-amount uint)
        (min-scholarship-amount uint)
        (institution (string-ascii 100))
        (field-of-study (string-ascii 100))
        (deadline-blocks uint)
    )
    (let (
            (pool-id (+ (var-get last-pool-id) u1))
            (current-block burn-block-height)
            (deadline (+ current-block deadline-blocks))
        )
        (asserts! (> target-amount u0) err-invalid-amount)
        (asserts! (> min-scholarship-amount u0) err-invalid-amount)
        (asserts! (> deadline-blocks u0) err-invalid-amount)
        (asserts! (<= min-scholarship-amount target-amount) err-invalid-amount)

        (map-set scholarship-pools pool-id {
            creator: tx-sender,
            title: title,
            description: description,
            target-amount: target-amount,
            current-amount: u0,
            min-scholarship-amount: min-scholarship-amount,
            institution: institution,
            field-of-study: field-of-study,
            is-active: true,
            created-at: current-block,
            deadline: deadline,
        })

        (var-set last-pool-id pool-id)
        (ok pool-id)
    )
)

(define-public (contribute-to-pool
        (pool-id uint)
        (amount uint)
    )
    (let (
            (pool-info (unwrap! (map-get? scholarship-pools pool-id) err-pool-not-found))
            (current-block burn-block-height)
            (current-contribution (get-user-contribution pool-id tx-sender))
            (new-contribution (+ current-contribution amount))
            (new-pool-amount (+ (get current-amount pool-info) amount))
            (contributors (get-pool-contributors pool-id))
        )
        (asserts! (get is-active pool-info) err-pool-inactive)
        (asserts! (< current-block (get deadline pool-info)) err-expired)
        (asserts! (> amount u0) err-invalid-amount)

        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        (map-set pool-contributions {
            pool-id: pool-id,
            contributor: tx-sender,
        }
            new-contribution
        )

        (map-set scholarship-pools pool-id
            (merge pool-info { current-amount: new-pool-amount })
        )

        (if (is-none (index-of contributors tx-sender))
            (map-set pool-contributors pool-id
                (unwrap-panic (as-max-len? (append contributors tx-sender) u100))
            )
            true
        )

        (ok true)
    )
)

(define-public (issue-scholarship-from-pool
        (pool-id uint)
        (recipient principal)
        (scholarship-amount uint)
        (expiry-blocks uint)
        (scholarship-id (string-ascii 50))
    )
    (let (
            (pool-info (unwrap! (map-get? scholarship-pools pool-id) err-pool-not-found))
            (pool-creator (get creator pool-info))
            (current-pool-amount (get current-amount pool-info))
            (min-amount (get min-scholarship-amount pool-info))
            (new-pool-amount (- current-pool-amount scholarship-amount))
        )
        (asserts! (is-eq tx-sender pool-creator) err-unauthorized)
        (asserts! (get is-active pool-info) err-pool-inactive)
        (asserts! (>= scholarship-amount min-amount) err-min-amount-not-met)
        (asserts! (>= current-pool-amount scholarship-amount)
            err-insufficient-pool-funds
        )

        (try! (as-contract (stx-transfer? scholarship-amount tx-sender recipient)))

        (map-set scholarship-pools pool-id
            (merge pool-info { current-amount: new-pool-amount })
        )

        (try! (issue-scholarship recipient (get institution pool-info)
            scholarship-amount (get field-of-study pool-info) expiry-blocks
            scholarship-id
        ))

        (ok true)
    )
)

(define-public (close-pool (pool-id uint))
    (let (
            (pool-info (unwrap! (map-get? scholarship-pools pool-id) err-pool-not-found))
            (pool-creator (get creator pool-info))
        )
        (asserts! (is-eq tx-sender pool-creator) err-unauthorized)
        (asserts! (get is-active pool-info) err-pool-inactive)

        (map-set scholarship-pools pool-id (merge pool-info { is-active: false }))

        (ok true)
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
