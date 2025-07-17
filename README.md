# 🎓 Tokenized Scholarships Smart Contract
A Clarity smart contract that issues scholarships as non-fungible tokens (NFTs) to prevent forgery and unauthorized resale. This innovative approach ensures scholarship authenticity while providing a secure and transparent system for educational funding.

## ✨ Features

- **🔒 Forgery Prevention**: Only authorized issuers can mint scholarship NFTs
- **🚫 Transfer Blocking**: Scholarships cannot be transferred or resold
- **⏰ Expiry Management**: Scholarships have built-in expiration dates
- **📊 Usage Tracking**: Track when and how scholarships are used
- **🏛️ Institution Management**: Organize scholarships by educational institutions
- **📈 Analytics**: Get statistics on scholarship usage and status

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository
2. Navigate to the project directory
3. Run `clarinet check` to verify the contract

## 📋 Contract Functions

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-scholarship-details` | Get complete scholarship information |
| `get-scholarship-status` | Get current status (active, used, expired) |
| `is-scholarship-valid` | Check if scholarship is still valid |
| `get-total-scholarships` | Get total number of scholarships issued |
| `get-scholarship-stats` | Get comprehensive statistics |
| `verify-scholarship-authenticity` | Verify scholarship was issued by authorized issuer |

### Public Functions

| Function | Description |
|----------|-------------|
| `issue-scholarship` | Issue a new scholarship NFT |
| `use-scholarship` | Mark scholarship as used |
| `extend-scholarship-expiry` | Extend scholarship expiration date |
| `revoke-scholarship` | Revoke an unused scholarship |
| `add-authorized-issuer` | Add new authorized issuer (owner only) |
| `remove-authorized-issuer` | Remove authorized issuer (owner only) |

## 🔧 Usage Examples

### Issue a Scholarship

```clarity
(contract-call? .tokenized-scholarships issue-scholarship
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM  ;; recipient
  "MIT"                                        ;; institution
  u50000                                       ;; amount (in micro-STX)
  "Computer Science"                           ;; field of study
  u52560                                       ;; expiry blocks (~1 year)
  "CS2024-001"                                 ;; scholarship ID
)
```

### Use a Scholarship

```clarity
(contract-call? .tokenized-scholarships use-scholarship
  u1                           ;; token ID
  "TX-2024-PAYMENT-001"        ;; transaction ID
)
```

### Check Scholarship Status

```clarity
(contract-call? .tokenized-scholarships get-scholarship-status u1)
```

## 🏗️ Contract Architecture

The contract uses the following key data structures:

- **NFT Definition**: `scholarship-nft` - The main NFT representing scholarships
- **Scholarship Details**: Comprehensive information about each scholarship
- **Institution Tracking**: Maps institutions to their issued scholarships
- **Usage Records**: Tracks when and how scholarships are used
- **Authorization**: Manages who can issue scholarships

## 🛡️ Security Features

1. **Authorization Control**: Only pre-approved issuers can mint scholarships
2. **Transfer Prevention**: `transfer` function always fails to prevent resale
3. **Expiry Enforcement**: Scholarships automatically expire after specified blocks
4. **Usage Tracking**: Detailed records of scholarship usage
5. **Authenticity Verification**: Built-in verification system

## 📊 Statistics and Analytics

The contract provides comprehensive analytics:

- Total scholarships issued
- Active scholarships count
- Used scholarships count
- Expired scholarships count
- Institution-specific statistics
- Recipient-specific statistics

## 🔄 Workflow

1. **Setup**: Contract owner authorizes institutions as issuers
2. **Issuance**: Authorized issuers create scholarship NFTs for recipients
3. **Verification**: Recipients can verify their scholarship authenticity
4. **Usage**: Recipients use scholarships for educational expenses
5. **Tracking**: All activities are recorded on-chain

## 🧪 Testing

Run the test suite:

```bash
npm install
npm test
```

## 📖 Error Codes

| Code | Description |
|------|-------------|
| `u100` | Owner only function |
| `u101` | Not token owner |
| `u104` | Scholarship not found |
| `u106` | Unauthorized issuer |
| `u107` | Invalid amount |
| `u108` | Scholarship expired |
| `u109` | Scholarship already used |
| `u110` | Transfer blocked |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.
