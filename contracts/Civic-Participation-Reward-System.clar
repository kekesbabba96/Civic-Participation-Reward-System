(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-activity-ended (err u106))
(define-constant err-already-participated (err u107))
(define-constant err-activity-not-active (err u108))

(define-fungible-token civic-token)

(define-data-var next-activity-id uint u1)
(define-data-var total-participants uint u0)
(define-data-var contract-balance uint u0)

(define-map activities
    { activity-id: uint }
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        reward-amount: uint,
        max-participants: uint,
        current-participants: uint,
        creator: principal,
        start-block: uint,
        end-block: uint,
        is-active: bool,
    }
)

(define-map participations
    {
        participant: principal,
        activity-id: uint,
    }
    {
        block-participated: uint,
        reward-claimed: bool,
    }
)

(define-map user-stats
    { user: principal }
    {
        total-activities: uint,
        total-rewards: uint,
        reputation-score: uint,
    }
)

(define-map activity-participants
    {
        activity-id: uint,
        participant: principal,
    }
    { participated: bool }
)

(define-read-only (get-activity (activity-id uint))
    (map-get? activities { activity-id: activity-id })
)

(define-read-only (get-participation
        (participant principal)
        (activity-id uint)
    )
    (map-get? participations {
        participant: participant,
        activity-id: activity-id,
    })
)

(define-read-only (get-user-stats (user principal))
    (default-to {
        total-activities: u0,
        total-rewards: u0,
        reputation-score: u0,
    }
        (map-get? user-stats { user: user })
    )
)

(define-read-only (has-participated
        (participant principal)
        (activity-id uint)
    )
    (is-some (map-get? activity-participants {
        activity-id: activity-id,
        participant: participant,
    }))
)

(define-read-only (get-balance (user principal))
    (ft-get-balance civic-token user)
)

(define-read-only (get-total-supply)
    (ft-get-supply civic-token)
)

(define-read-only (get-next-activity-id)
    (var-get next-activity-id)
)

(define-read-only (get-total-participants)
    (var-get total-participants)
)

(define-read-only (get-contract-balance)
    (var-get contract-balance)
)

(define-read-only (is-activity-active (activity-id uint))
    (match (get-activity activity-id)
        activity (and
            (get is-active activity)
            (>= stacks-block-height (get start-block activity))
            (< stacks-block-height (get end-block activity))
        )
        false
    )
)

(define-public (create-activity
        (name (string-ascii 50))
        (description (string-ascii 200))
        (reward-amount uint)
        (max-participants uint)
        (duration-blocks uint)
    )
    (let (
            (activity-id (var-get next-activity-id))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height duration-blocks))
        )
        (asserts! (> reward-amount u0) err-invalid-amount)
        (asserts! (> max-participants u0) err-invalid-amount)
        (asserts! (> duration-blocks u0) err-invalid-amount)

        (map-set activities { activity-id: activity-id } {
            name: name,
            description: description,
            reward-amount: reward-amount,
            max-participants: max-participants,
            current-participants: u0,
            creator: tx-sender,
            start-block: start-block,
            end-block: end-block,
            is-active: true,
        })

        (var-set next-activity-id (+ activity-id u1))
        (ok activity-id)
    )
)

(define-public (participate-in-activity (activity-id uint))
    (let (
            (activity (unwrap! (get-activity activity-id) err-not-found))
            (current-participants (get current-participants activity))
        )
        (asserts! (not (has-participated tx-sender activity-id))
            err-already-participated
        )
        (asserts! (is-activity-active activity-id) err-activity-not-active)
        (asserts! (< current-participants (get max-participants activity))
            err-activity-ended
        )

        (map-set activity-participants {
            activity-id: activity-id,
            participant: tx-sender,
        } { participated: true }
        )

        (map-set participations {
            participant: tx-sender,
            activity-id: activity-id,
        } {
            block-participated: stacks-block-height,
            reward-claimed: false,
        })

        (map-set activities { activity-id: activity-id }
            (merge activity { current-participants: (+ current-participants u1) })
        )

        (var-set total-participants (+ (var-get total-participants) u1))
        (ok true)
    )
)

(define-public (claim-reward (activity-id uint))
    (let (
            (activity (unwrap! (get-activity activity-id) err-not-found))
            (participation (unwrap! (get-participation tx-sender activity-id) err-not-found))
            (reward-amount (get reward-amount activity))
            (user-current-stats (get-user-stats tx-sender))
        )
        (asserts! (not (get reward-claimed participation)) err-already-exists)
        (asserts! (>= stacks-block-height (get end-block activity))
            err-activity-not-active
        )

        (try! (ft-mint? civic-token reward-amount tx-sender))

        (map-set participations {
            participant: tx-sender,
            activity-id: activity-id,
        }
            (merge participation { reward-claimed: true })
        )

        (map-set user-stats { user: tx-sender } {
            total-activities: (+ (get total-activities user-current-stats) u1),
            total-rewards: (+ (get total-rewards user-current-stats) reward-amount),
            reputation-score: (+ (get reputation-score user-current-stats) u10),
        })

        (var-set contract-balance (+ (var-get contract-balance) reward-amount))
        (ok reward-amount)
    )
)

(define-public (deactivate-activity (activity-id uint))
    (let ((activity (unwrap! (get-activity activity-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator activity)) err-unauthorized)

        (map-set activities { activity-id: activity-id }
            (merge activity { is-active: false })
        )
        (ok true)
    )
)

(define-public (transfer-tokens
        (amount uint)
        (recipient principal)
    )
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (ft-transfer? civic-token amount tx-sender recipient)
    )
)

(define-public (mint-admin-tokens
        (amount uint)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> amount u0) err-invalid-amount)
        (ft-mint? civic-token amount recipient)
    )
)

(define-public (burn-tokens (amount uint))
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (ft-burn? civic-token amount tx-sender)
    )
)

(define-public (batch-create-activities (activities-data (list 10
    {
    name: (string-ascii 50),
    description: (string-ascii 200),
    reward-amount: uint,
    max-participants: uint,
    duration-blocks: uint,
})))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map create-single-activity activities-data))
    )
)

(define-private (create-single-activity (activity-data {
    name: (string-ascii 50),
    description: (string-ascii 200),
    reward-amount: uint,
    max-participants: uint,
    duration-blocks: uint,
}))
    (create-activity (get name activity-data) (get description activity-data)
        (get reward-amount activity-data)
        (get max-participants activity-data)
        (get duration-blocks activity-data)
    )
)

(define-read-only (get-activities-by-creator (creator principal))
    (ok creator)
)

(define-read-only (calculate-reputation-bonus (user principal))
    (let (
            (stats (get-user-stats user))
            (total-activities (get total-activities stats))
            (reputation-score (get reputation-score stats))
        )
        (if (>= total-activities u10)
            (if (>= reputation-score u100)
                u50
                u25
            )
            u0
        )
    )
)

(define-public (claim-reputation-bonus)
    (let (
            (bonus-amount (calculate-reputation-bonus tx-sender))
            (user-current-stats (get-user-stats tx-sender))
        )
        (asserts! (> bonus-amount u0) err-invalid-amount)

        (try! (ft-mint? civic-token bonus-amount tx-sender))

        (map-set user-stats { user: tx-sender }
            (merge user-current-stats { total-rewards: (+ (get total-rewards user-current-stats) bonus-amount) })
        )
        (ok bonus-amount)
    )
)

(define-read-only (get-leaderboard-stats (user principal))
    (let (
            (stats (get-user-stats user))
            (balance (get-balance user))
        )
        {
            user: user,
            total-activities: (get total-activities stats),
            total-rewards: (get total-rewards stats),
            reputation-score: (get reputation-score stats),
            current-balance: balance,
        }
    )
)

(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok true)
    )
)
