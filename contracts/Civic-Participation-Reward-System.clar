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
(define-constant err-voting-ended (err u109))
(define-constant err-already-voted (err u110))
(define-constant err-insufficient-reputation (err u111))
(define-constant err-milestone-not-found (err u112))
(define-constant err-milestone-already-completed (err u113))
(define-constant err-invalid-milestone-order (err u114))
(define-constant err-milestone-requirements-not-met (err u115))
(define-constant err-announcement-not-found (err u116))
(define-constant err-announcement-expired (err u117))
(define-constant err-invalid-category (err u118))
(define-constant err-not-authorized-creator (err u119))
(define-constant min-reputation-to-vote u50)
(define-constant max-milestones-per-activity u5)

(define-fungible-token civic-token)

(define-data-var next-activity-id uint u1)
(define-data-var total-participants uint u0)
(define-data-var contract-balance uint u0)
(define-data-var voting-period-blocks uint u1440)
(define-data-var next-announcement-id uint u1)

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
        approval-status: (string-ascii 10),
        votes-for: uint,
        votes-against: uint,
        voting-end-block: uint,
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

(define-map activity-votes
    {
        activity-id: uint,
        voter: principal,
    }
    {
        vote: bool,
        block-voted: uint,
    }
)

(define-map activity-milestones
    {
        activity-id: uint,
        milestone-id: uint,
    }
    {
        name: (string-ascii 50),
        description: (string-ascii 100),
        reward-amount: uint,
        required-blocks-elapsed: uint,
        is-final: bool,
    }
)

(define-map user-milestone-progress
    {
        user: principal,
        activity-id: uint,
        milestone-id: uint,
    }
    {
        completed: bool,
        completion-block: uint,
        reward-claimed: bool,
    }
)

(define-map activity-milestone-count
    { activity-id: uint }
    { count: uint }
)

(define-map announcements
    { announcement-id: uint }
    {
        title: (string-ascii 100),
        content: (string-ascii 500),
        category: (string-ascii 30),
        creator: principal,
        created-at: uint,
        expiry-block: uint,
        is-active: bool,
    }
)

(define-map authorized-announcers
    { user: principal }
    { authorized: bool }
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
            (is-eq (get approval-status activity) "approved")
            (>= stacks-block-height (get start-block activity))
            (< stacks-block-height (get end-block activity))
        )
        false
    )
)

(define-read-only (has-voted
        (voter principal)
        (activity-id uint)
    )
    (is-some (map-get? activity-votes {
        activity-id: activity-id,
        voter: voter,
    }))
)

(define-read-only (get-vote-status (activity-id uint))
    (match (get-activity activity-id)
        activity
        {
            votes-for: (get votes-for activity),
            votes-against: (get votes-against activity),
            approval-status: (get approval-status activity),
            voting-end-block: (get voting-end-block activity),
        }
        {
            votes-for: u0,
            votes-against: u0,
            approval-status: "not-found",
            voting-end-block: u0,
        }
    )
)

(define-read-only (is-voting-active (activity-id uint))
    (match (get-activity activity-id)
        activity (and
            (is-eq (get approval-status activity) "pending")
            (< stacks-block-height (get voting-end-block activity))
        )
        false
    )
)

(define-read-only (get-milestone
        (activity-id uint)
        (milestone-id uint)
    )
    (map-get? activity-milestones {
        activity-id: activity-id,
        milestone-id: milestone-id,
    })
)

(define-read-only (get-user-milestone-progress
        (user principal)
        (activity-id uint)
        (milestone-id uint)
    )
    (map-get? user-milestone-progress {
        user: user,
        activity-id: activity-id,
        milestone-id: milestone-id,
    })
)

(define-read-only (get-activity-milestone-count (activity-id uint))
    (default-to u0
        (get count
            (map-get? activity-milestone-count { activity-id: activity-id })
        ))
)

(define-read-only (is-milestone-available
        (user principal)
        (activity-id uint)
        (milestone-id uint)
    )
    (let (
            (milestone (map-get? activity-milestones {
                activity-id: activity-id,
                milestone-id: milestone-id,
            }))
            (user-participation (get-participation user activity-id))
        )
        (match milestone
            milestone-data (match user-participation
                participation-data (let (
                        (blocks-since-participation (- stacks-block-height
                            (get block-participated participation-data)
                        ))
                        (required-blocks (get required-blocks-elapsed milestone-data))
                    )
                    (>= blocks-since-participation required-blocks)
                )
                false
            )
            false
        )
    )
)

(define-read-only (has-completed-milestone
        (user principal)
        (activity-id uint)
        (milestone-id uint)
    )
    (default-to false
        (get completed
            (get-user-milestone-progress user activity-id milestone-id)
        ))
)

(define-read-only (get-announcement (announcement-id uint))
    (map-get? announcements { announcement-id: announcement-id })
)

(define-read-only (get-next-announcement-id)
    (var-get next-announcement-id)
)

(define-read-only (is-authorized-announcer (user principal))
    (or
        (is-eq user contract-owner)
        (default-to false
            (get authorized
                (map-get? authorized-announcers { user: user })
            )
        )
    )
)

(define-read-only (is-announcement-active (announcement-id uint))
    (match (get-announcement announcement-id)
        announcement (and
            (get is-active announcement)
            (< stacks-block-height (get expiry-block announcement))
        )
        false
    )
)

(define-read-only (get-announcement-with-status (announcement-id uint))
    (match (get-announcement announcement-id)
        announcement
        (some {
            title: (get title announcement),
            content: (get content announcement),
            category: (get category announcement),
            creator: (get creator announcement),
            created-at: (get created-at announcement),
            expiry-block: (get expiry-block announcement),
            is-active: (get is-active announcement),
            is-expired: (>= stacks-block-height (get expiry-block announcement)),
        })
        none
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
            is-active: false,
            approval-status: "pending",
            votes-for: u0,
            votes-against: u0,
            voting-end-block: (+ stacks-block-height (var-get voting-period-blocks)),
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

(define-public (batch-create-activities (activities-data (list
    10
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        reward-amount: uint,
        max-participants: uint,
        duration-blocks: uint,
    }
)))
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

(define-public (vote-on-activity
        (activity-id uint)
        (vote-for bool)
    )
    (let (
            (activity (unwrap! (get-activity activity-id) err-not-found))
            (voter-stats (get-user-stats tx-sender))
        )
        (asserts! (>= (get reputation-score voter-stats) min-reputation-to-vote)
            err-insufficient-reputation
        )
        (asserts! (not (has-voted tx-sender activity-id)) err-already-voted)
        (asserts! (is-voting-active activity-id) err-voting-ended)

        (map-set activity-votes {
            activity-id: activity-id,
            voter: tx-sender,
        } {
            vote: vote-for,
            block-voted: stacks-block-height,
        })

        (let (
                (new-votes-for (if vote-for
                    (+ (get votes-for activity) u1)
                    (get votes-for activity)
                ))
                (new-votes-against (if vote-for
                    (get votes-against activity)
                    (+ (get votes-against activity) u1)
                ))
            )
            (map-set activities { activity-id: activity-id }
                (merge activity {
                    votes-for: new-votes-for,
                    votes-against: new-votes-against,
                })
            )
        )
        (ok true)
    )
)

(define-public (finalize-voting (activity-id uint))
    (let (
            (activity (unwrap! (get-activity activity-id) err-not-found))
            (votes-for (get votes-for activity))
            (votes-against (get votes-against activity))
            (total-votes (+ votes-for votes-against))
        )
        (asserts! (not (is-voting-active activity-id)) err-voting-ended)
        (asserts! (is-eq (get approval-status activity) "pending")
            err-already-exists
        )

        (let (
                (approval-threshold (/ total-votes u2))
                (is-approved (> votes-for approval-threshold))
            )
            (map-set activities { activity-id: activity-id }
                (merge activity {
                    approval-status: (if is-approved
                        "approved"
                        "rejected"
                    ),
                    is-active: is-approved,
                })
            )
            (ok is-approved)
        )
    )
)

(define-public (create-milestone
        (activity-id uint)
        (name (string-ascii 50))
        (description (string-ascii 100))
        (reward-amount uint)
        (required-blocks-elapsed uint)
        (is-final bool)
    )
    (let (
            (activity (unwrap! (get-activity activity-id) err-not-found))
            (current-milestone-count (get-activity-milestone-count activity-id))
            (new-milestone-id (+ current-milestone-count u1))
        )
        (asserts! (is-eq tx-sender (get creator activity)) err-unauthorized)
        (asserts! (< current-milestone-count max-milestones-per-activity)
            err-invalid-amount
        )
        (asserts! (> reward-amount u0) err-invalid-amount)

        (map-set activity-milestones {
            activity-id: activity-id,
            milestone-id: new-milestone-id,
        } {
            name: name,
            description: description,
            reward-amount: reward-amount,
            required-blocks-elapsed: required-blocks-elapsed,
            is-final: is-final,
        })

        (map-set activity-milestone-count { activity-id: activity-id } { count: new-milestone-id })
        (ok new-milestone-id)
    )
)

(define-public (complete-milestone
        (activity-id uint)
        (milestone-id uint)
    )
    (let (
            (milestone (unwrap! (get-milestone activity-id milestone-id)
                err-milestone-not-found
            ))
            (activity (unwrap! (get-activity activity-id) err-not-found))
            (user-participation (unwrap! (get-participation tx-sender activity-id) err-not-found))
        )
        (asserts! (is-activity-active activity-id) err-activity-not-active)
        (asserts!
            (not (has-completed-milestone tx-sender activity-id milestone-id))
            err-milestone-already-completed
        )
        (asserts! (is-milestone-available tx-sender activity-id milestone-id)
            err-milestone-requirements-not-met
        )

        (map-set user-milestone-progress {
            user: tx-sender,
            activity-id: activity-id,
            milestone-id: milestone-id,
        } {
            completed: true,
            completion-block: stacks-block-height,
            reward-claimed: false,
        })
        (ok true)
    )
)

(define-public (claim-milestone-reward
        (activity-id uint)
        (milestone-id uint)
    )
    (let (
            (milestone (unwrap! (get-milestone activity-id milestone-id)
                err-milestone-not-found
            ))
            (progress (unwrap!
                (get-user-milestone-progress tx-sender activity-id milestone-id)
                err-not-found
            ))
            (reward-amount (get reward-amount milestone))
            (user-current-stats (get-user-stats tx-sender))
        )
        (asserts! (get completed progress) err-milestone-requirements-not-met)
        (asserts! (not (get reward-claimed progress)) err-already-exists)

        (try! (ft-mint? civic-token reward-amount tx-sender))

        (map-set user-milestone-progress {
            user: tx-sender,
            activity-id: activity-id,
            milestone-id: milestone-id,
        }
            (merge progress { reward-claimed: true })
        )

        (map-set user-stats { user: tx-sender } {
            total-activities: (get total-activities user-current-stats),
            total-rewards: (+ (get total-rewards user-current-stats) reward-amount),
            reputation-score: (+ (get reputation-score user-current-stats) u5),
        })
        (ok reward-amount)
    )
)

(define-public (authorize-announcer (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-announcers { user: user } { authorized: true })
        (ok true)
    )
)

(define-public (revoke-announcer (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-announcers { user: user } { authorized: false })
        (ok true)
    )
)

(define-public (create-announcement
        (title (string-ascii 100))
        (content (string-ascii 500))
        (category (string-ascii 30))
        (duration-blocks uint)
    )
    (let (
            (announcement-id (var-get next-announcement-id))
            (expiry-block (+ stacks-block-height duration-blocks))
        )
        (asserts! (is-authorized-announcer tx-sender) err-not-authorized-creator)
        (asserts! (> duration-blocks u0) err-invalid-amount)
        (asserts! (> (len title) u0) err-invalid-amount)
        (asserts! (> (len content) u0) err-invalid-amount)
        (asserts! (> (len category) u0) err-invalid-category)

        (map-set announcements { announcement-id: announcement-id } {
            title: title,
            content: content,
            category: category,
            creator: tx-sender,
            created-at: stacks-block-height,
            expiry-block: expiry-block,
            is-active: true,
        })

        (var-set next-announcement-id (+ announcement-id u1))
        (ok announcement-id)
    )
)

(define-public (update-announcement
        (announcement-id uint)
        (title (string-ascii 100))
        (content (string-ascii 500))
        (category (string-ascii 30))
    )
    (let (
            (announcement (unwrap! (get-announcement announcement-id) err-announcement-not-found))
        )
        (asserts! (is-eq tx-sender (get creator announcement)) err-unauthorized)
        (asserts! (get is-active announcement) err-announcement-expired)
        (asserts! (< stacks-block-height (get expiry-block announcement)) err-announcement-expired)
        (asserts! (> (len title) u0) err-invalid-amount)
        (asserts! (> (len content) u0) err-invalid-amount)
        (asserts! (> (len category) u0) err-invalid-category)

        (map-set announcements { announcement-id: announcement-id }
            (merge announcement {
                title: title,
                content: content,
                category: category,
            })
        )
        (ok true)
    )
)

(define-public (deactivate-announcement (announcement-id uint))
    (let (
            (announcement (unwrap! (get-announcement announcement-id) err-announcement-not-found))
        )
        (asserts! 
            (or
                (is-eq tx-sender (get creator announcement))
                (is-eq tx-sender contract-owner)
            )
            err-unauthorized
        )

        (map-set announcements { announcement-id: announcement-id }
            (merge announcement { is-active: false })
        )
        (ok true)
    )
)
