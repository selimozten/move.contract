# NFT Collection Smart Contract Documentation

## Table of Contents
1. [Overview](#overview)
2. [Key Structs](#key-structs)
3. [Constants](#constants)
4. [Error Codes](#error-codes)
5. [Core Functions](#core-functions)
6. [Helper Functions](#helper-functions)
7. [Events](#events)
8. [Security Measures](#security-measures)
9. [Testing](#testing)

## 1. Overview

This smart contract implements a comprehensive NFT (Non-Fungible Token) collection system on the Sui blockchain. It provides functionality for creating collections, minting NFTs, managing whitelists, handling royalties, and implementing various security measures.

## 2. Key Structs

### NFT
Represents an individual NFT within the collection.
- Fields:
  - `id`: Unique identifier
  - `name`: Name of the NFT
  - `description`: Description of the NFT
  - `url`: URL to the NFT's media
  - `creator`: Address of the NFT's creator
  - `revealed`: Boolean indicating if the NFT has been revealed
  - `reveal_time`: Timestamp for when the NFT can be revealed
  - `attributes`: Additional attributes of the NFT

### Collection
Represents the entire NFT collection.
- Fields:
  - `id`: Unique identifier
  - `name`: Name of the collection
  - `symbol`: Symbol of the collection
  - `description`: Description of the collection
  - `creator`: Address of the collection creator
  - `royalty_percentage`: Percentage of royalties for secondary sales
  - `price`: Price to mint an NFT
  - `minting_start`: Start time for minting
  - `minting_end`: End time for minting
  - `reveal_time`: Time when NFTs can be revealed
  - `max_supply`: Maximum number of NFTs that can be minted
  - `current_supply`: Current number of minted NFTs
  - `treasury`: Balance of collected funds
  - `paused`: Boolean to pause minting
  - `whitelist`: Table of whitelisted addresses
  - `upgradable`: Boolean indicating if the collection can be upgraded
  - `reentrancy_guard`: Boolean to prevent reentrancy attacks
  - `version`: Version number of the collection
  - `roles`: Table of user roles
  - `pending_withdrawals`: Table of pending withdrawal requests
  - `withdrawal_time_lock`: Time lock for withdrawals
  - `multisig_approvals`: Table for multi-signature approvals

### AdminCap
Represents the administrative capabilities for the collection.
- Fields:
  - `id`: Unique identifier
  - `collection_id`: ID of the associated collection
  - `expiry`: Expiration time of the admin capabilities

### ReentrancyGuard
A struct used to prevent reentrancy attacks.

### PendingWithdrawal
Represents a pending withdrawal request.
- Fields:
  - `amount`: Amount to be withdrawn
  - `request_time`: Time when the withdrawal was requested

## 3. Constants

- `MAX_NAME_LENGTH`: 50
- `MAX_DESCRIPTION_LENGTH`: 500
- `MAX_URL_LENGTH`: 100
- `MAX_WHITELIST_BATCH`: 1000
- `MAX_ATTRIBUTE_KEY_LENGTH`: 30
- `MAX_ATTRIBUTE_VALUE_LENGTH`: 50
- `REVEAL_GRACE_PERIOD`: 24 hours (in milliseconds)
- `MIN_ROYALTY_PERCENTAGE`: 1
- `MAX_ROYALTY_PERCENTAGE`: 20
- `DEFAULT_ADMIN_CAP_EXPIRY`: 1 year (in milliseconds)
- `ADMIN_CAP_EXPIRY_WARNING`: 30 days (in milliseconds)
- `ADMIN_CAP_GRACE_PERIOD`: 7 days (in milliseconds)
- `DEFAULT_WITHDRAWAL_TIME_LOCK`: 24 hours (in milliseconds)
- `MULTISIG_THRESHOLD`: 2 (number of signatures required for multi-sig operations)

## 4. Error Codes

- `ENOT_OWNER`: 0
- `EINSUFFICIENT_PAYMENT`: 1
- `EINVALID_ROYALTY_PERCENTAGE`: 2
- `EMINTING_NOT_STARTED`: 3
- `EMINTING_ENDED`: 4
- `EMAX_SUPPLY_REACHED`: 5
- `ENOT_REVEALED`: 6
- `ENOT_WHITELISTED`: 7
- `EMINTING_PAUSED`: 8
- `EINVALID_NAME_LENGTH`: 9
- `EINVALID_DESCRIPTION_LENGTH`: 10
- `EINVALID_URL_LENGTH`: 11
- `EINVALID_WITHDRAW_AMOUNT`: 12
- `EREENTRANCY`: 13
- `EMINTING_START_AFTER_END`: 14
- `EREVEAL_TIME_BEFORE_START`: 15
- `EREVEAL_TIME_AFTER_MINTING_END`: 16
- `EINVALID_ATTRIBUTE_KEY`: 17
- `EUPGRADE_NOT_ALLOWED`: 18
- `EBATCH_SIZE_EXCEEDED`: 19
- `EWHITELIST_EXPIRED`: 20
- `EADMIN_CAP_EXPIRED`: 21
- `EINVALID_ADMIN_CAP_EXPIRY`: 22
- `EINVALID_URL_FORMAT`: 23
- `EINVALID_UTF8_FORMAT`: 24
- `EADMIN_CAP_IN_GRACE_PERIOD`: 25
- `EINSUFFICIENT_ROLE`: 26
- `EINVALID_ROLE`: 27
- `EWITHDRAWAL_TIME_LOCK_NOT_EXPIRED`: 28
- `EINVALID_WITHDRAWAL_TIME_LOCK`: 29
- `EINVALID_TIME_SETTINGS`: 30
- `EINVALID_INPUT`: 31
- `EINSUFFICIENT_TREASURY_BALANCE`: 32
- `EMULTISIG_THRESHOLD_NOT_MET`: 33

## 5. Core Functions

### create_collection
Creates a new NFT collection.
- Parameters:
  - `name`: Name of the collection
  - `symbol`: Symbol of the collection
  - `description`: Description of the collection
  - `royalty_percentage`: Royalty percentage for secondary sales
  - `price`: Price to mint an NFT
  - `minting_start`: Start time for minting
  - `minting_end`: End time for minting
  - `reveal_time`: Time when NFTs can be revealed
  - `max_supply`: Maximum number of NFTs that can be minted
  - `upgradable`: Whether the collection can be upgraded
  - `admin_cap_expiry`: Optional expiry time for admin capabilities
  - `withdrawal_time_lock`: Optional time lock for withdrawals
  - `clock`: Sui Clock object
  - `ctx`: Transaction context

### mint_nft
Mints a new NFT in the collection.
- Parameters:
  - `collection`: Mutable reference to the Collection
  - `name`: Name of the NFT
  - `description`: Description of the NFT
  - `url`: URL to the NFT's media
  - `payment`: Mutable reference to the payment Coin
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

### reveal_nft
Reveals an NFT after the reveal time has passed.
- Parameters:
  - `nft`: Mutable reference to the NFT
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

### request_withdrawal
Requests a withdrawal from the collection's treasury.
- Parameters:
  - `collection`: Mutable reference to the Collection
  - `amount`: Amount to withdraw
  - `admin_cap`: Reference to the AdminCap
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

### execute_withdrawal
Executes a previously requested withdrawal.
- Parameters:
  - `collection`: Mutable reference to the Collection
  - `admin_cap`: Reference to the AdminCap
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

### update_collection
Updates various parameters of the collection.
- Parameters:
  - `collection`: Mutable reference to the Collection
  - `field`: Field to update (e.g., "price", "minting_end", "paused", "withdrawal_time_lock")
  - `value`: New value for the field
  - `admin_cap`: Reference to the AdminCap
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

### add_to_whitelist
Adds addresses to the whitelist.
- Parameters:
  - `collection`: Mutable reference to the Collection
  - `addresses`: Vector of addresses to whitelist
  - `expiry`: Expiry time for the whitelist entries
  - `admin_cap`: Reference to the AdminCap
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

### remove_from_whitelist
Removes addresses from the whitelist.
- Parameters:
  - `collection`: Mutable reference to the Collection
  - `addresses`: Vector of addresses to remove from the whitelist
  - `admin_cap`: Reference to the AdminCap
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

### update_role
Updates the role of a user in the collection.
- Parameters:
  - `collection`: Mutable reference to the Collection
  - `user`: Address of the user
  - `new_role`: New role bitmask for the user
  - `admin_cap`: Reference to the AdminCap
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

### extend_admin_cap_expiry
Extends the expiry of the AdminCap.
- Parameters:
  - `collection`: Mutable reference to the Collection
  - `admin_cap`: Mutable reference to the AdminCap
  - `new_expiry`: New expiry time for the AdminCap
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

### trigger_fail_safe
Triggers a fail-safe mechanism to pause the collection.
- Parameters:
  - `collection`: Mutable reference to the Collection
  - `admin_cap`: Reference to the AdminCap
  - `clock`: Reference to the Sui Clock object
  - `ctx`: Transaction context

## 6. Helper Functions

### acquire_reentrancy_guard
Acquires a reentrancy guard to prevent recursive calls.

### is_address_whitelisted
Checks if an address is whitelisted for minting.

### check_admin_cap_expiry
Checks if the AdminCap is nearing expiry and emits a warning event if necessary.

### has_role
Checks if an address has a specific role in the collection.

### is_valid_role
Validates if a role bitmask is valid.

### is_valid_utf8
Performs a basic UTF-8 validation on input.

### is_valid_url
Performs a basic URL validation on input.

### get_price
Returns the current minting price of the collection.

### get_treasury_balance
Returns the current balance of the collection's treasury.

### is_admin_cap_in_grace_period
Checks if the AdminCap is in the grace period after expiry.

## 7. Events

### NFTMinted
Emitted when an NFT is minted.

### CollectionCreated
Emitted when a new collection is created.

### NFTRevealed
Emitted when an NFT is revealed.

### FundsWithdrawn
Emitted when funds are withdrawn from the treasury.

### CollectionUpdated
Emitted when the collection parameters are updated.

### WhitelistBatchUpdated
Emitted when the whitelist is updated (add or remove).

### AdminCapNearExpiry
Emitted when the AdminCap is nearing expiry.

### WithdrawalRequested
Emitted when a withdrawal is requested.

### WithdrawalExecutionReady
Emitted when a withdrawal is ready for execution.

### RoleUpdated
Emitted when a user's role is updated.

### MultiSigApprovalAdded
Emitted when a multi-signature approval is added.

## 8. Security Measures

1. **Reentrancy Guard**: Prevents recursive calls to sensitive functions.
2. **Role-based Access Control**: Ensures only authorized users can perform certain actions.
3. **Admin Capability Expiry**: Limits the lifetime of administrative privileges.
4. **Withdrawal Time Lock**: Introduces a delay between requesting and executing withdrawals.
5. **Multi-signature Approvals**: Requires multiple approvals for critical operations.
6. **Input Validation**: Checks for valid inputs (e.g., UTF-8 encoding, URL format).
7. **Fail-safe Mechanism**: Allows pausing the contract in case of emergencies.
8. **Whitelist Management**: Controls who can mint NFTs during restricted periods.

## 9. Testing

The contract includes a comprehensive test module (`collection_tests`) with the following test cases:

1. `test_create_collection`: Tests the creation of a new collection.
2. `test_mint_nft`: Tests the minting of an NFT.
3. `test_whitelist_operations`: Tests adding and removing addresses from the whitelist.
4. `test_update_collection`: Tests updating collection parameters.
5. `test_withdrawal_process`: Tests the withdrawal request and execution process.
6. `test_unauthorized_mint`: Tests that unauthorized addresses cannot mint NFTs.
7. `test_admin_cap_expiry`: Tests the AdminCap expiry and extension process.
8. `test_fail_safe_mechanism`: Tests the fail-safe mechanism to pause the collection.

These tests cover various aspects of the contract's functionality and security measures. They use Sui's `test_scenario` module to simulate transactions and check the contract's behavior under different conditions.

To run the tests, use the Sui CLI command:
```
sui move test
```

This documentation provides a comprehensive overview of the NFT Collection smart contract, its core functionality, security measures, and testing procedures. Developers and users can refer to this document to understand the contract's capabilities and how to interact with it safely and effectively.
