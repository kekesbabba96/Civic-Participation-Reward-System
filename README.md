# 🏛️ Civic Participation Reward System

A blockchain-based smart contract system that incentivizes civic engagement by rewarding citizens for participating in community activities and events.

## 🌟 Features

- **🎯 Activity Creation**: Create civic activities with customizable rewards and participant limits
- **🏆 Participation Tracking**: Track user participation across multiple civic activities
- **💰 Token Rewards**: Earn civic tokens for participating in community events
- **📊 Reputation System**: Build reputation scores based on participation history
- **🎁 Bonus Rewards**: Unlock special bonuses for active community members
- **👥 Leaderboards**: View participation statistics and community rankings

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Run `clarinet check` to verify the contract

## 📋 Contract Functions

### Public Functions

#### 🏗️ Activity Management

**`create-activity`**
```clarity
(create-activity name description reward-amount max-participants duration-blocks)
```
Creates a new civic activity with specified parameters.

**`participate-in-activity`**
```clarity
(participate-in-activity activity-id)
```
Register participation in a specific civic activity.

**`claim-reward`**
```clarity
(claim-reward activity-id)
```
Claim tokens after activity completion.

**`deactivate-activity`**
```clarity
(deactivate-activity activity-id)
```
Deactivate an activity (only by creator).

#### 💳 Token Operations

**`transfer-tokens`**
```clarity
(transfer-tokens amount recipient)
```
Transfer civic tokens to another user.

**`mint-admin-tokens`**
```clarity
(mint-admin-tokens amount recipient)
```
Mint tokens (admin only).

**`burn-tokens`**
```clarity
(burn-tokens amount)
```
Burn your own tokens.

#### 🎁 Reward System

**`claim-reputation-bonus`**
```clarity
(claim-reputation-bonus)
```
Claim bonus rewards based on reputation score.

**`batch-create-activities`**
```clarity
(batch-create-activities activities-data)
```
Create multiple activities at once (admin only).

### Read-Only Functions

#### 📖 Information Retrieval

- `get-activity` - Get activity details
- `get-participation` - Get user participation info
- `get-user-stats` - Get user statistics
- `get-balance` - Get token balance
- `get-total-supply` - Get total token supply
- `has-participated` - Check if user participated in activity
- `is-activity-active` - Check if activity is currently active
- `get-leaderboard-stats` - Get comprehensive user stats
- `calculate-reputation-bonus` - Calculate available bonus

## 🎮 Usage Examples

### Creating an Activity
```clarity
(contract-call? .civic-participation-reward-system create-activity 
  "Community Cleanup"
  "Join us for a neighborhood cleanup event"
  u100
  u50
  u1440)  ;; 1 day in blocks
```

### Participating in an Activity
```clarity
(contract-call? .civic-participation-reward-system participate-in-activity u1)
```

### Claiming Rewards
```clarity
(contract-call? .civic-participation-reward-system claim-reward u1)
```

## 🏅 Reputation System

The contract implements a reputation system that rewards consistent participation:

- **+10 reputation points** for each completed activity
- **Bonus eligibility**: 
  - 10+ activities + 100+ reputation = 50 token bonus
  - 10+ activities + <100 reputation = 25 token bonus
  - <10 activities = no bonus

## 💎 Token Economics

- **Civic Token (civic-token)**: Native fungible token for rewards
- **Dynamic Supply**: Tokens minted based on participation
- **Transferable**: Users can transfer tokens between accounts
- **Burnable**: Users can burn their own tokens if desired

## 🔐 Security Features

- **Owner Controls**: Admin functions restricted to contract owner
- **Duplicate Prevention**: Users cannot participate twice in same activity
- **Time Validation**: Activities have start/end blocks
- **Balance Checks**: Prevents invalid token operations

## 📊 Data Structures

### Activities
- Name, description, reward amount
- Participant limits and current count
- Creator, start/end blocks, active status

### User Stats
- Total activities participated
- Total rewards earned
- Reputation score

### Participation Records
- Block participated, reward claim status
- Activity-specific participation tracking


## 📄 License

This project is open source and available under the MIT License.

## 🆘 Support

For questions or issues, please open an issue on the GitHub repository.

---

*Made with ❤️ for stronger communities through blockchain technology*
