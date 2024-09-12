// SPDX-License-Identifier: MIT
module nft_collection::collection {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::url::{Self, Url};
    use sui::event;
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Self, Option};

    // Error codes
    const ENOT_OWNER: u64 = 0;
    const EINSUFFICIENT_PAYMENT: u64 = 1;
    const EINVALID_ROYALTY_PERCENTAGE: u64 = 2;
    const EMINTING_NOT_STARTED: u64 = 3;
    const EMINTING_ENDED: u64 = 4;
    const EMAX_SUPPLY_REACHED: u64 = 5;
    const ENOT_REVEALED: u64 = 6;
    const ENOT_WHITELISTED: u64 = 7;
    const EMINTING_PAUSED: u64 = 8;
    const EINVALID_NAME_LENGTH: u64 = 9;
    const EINVALID_DESCRIPTION_LENGTH: u64 = 10;
    const EINVALID_URL_LENGTH: u64 = 11;
    const EINVALID_WITHDRAW_AMOUNT: u64 = 12;
    const EREENTRANCY: u64 = 13;
    const EMINTING_START_AFTER_END: u64 = 14;
    const EREVEAL_TIME_BEFORE_START: u64 = 15;
    const EREVEAL_TIME_AFTER_MINTING_END: u64 = 16;
    const EINVALID_ATTRIBUTE_KEY: u64 = 17;
    const EUPGRADE_NOT_ALLOWED: u64 = 18;
    const EBATCH_SIZE_EXCEEDED: u64 = 19;
    const EWHITELIST_EXPIRED: u64 = 20;
    const EADMIN_CAP_EXPIRED: u64 = 21;
    const EINVALID_ADMIN_CAP_EXPIRY: u64 = 22;
    const EINVALID_URL_FORMAT: u64 = 23;
    const EINVALID_UTF8_FORMAT: u64 = 24;
    const EADMIN_CAP_IN_GRACE_PERIOD: u64 = 25;
    const EINSUFFICIENT_ROLE: u64 = 26;
    const EINVALID_ROLE: u64 = 27;
    const EWITHDRAWAL_TIME_LOCK_NOT_EXPIRED: u64 = 28;
    const EINVALID_WITHDRAWAL_TIME_LOCK: u64 = 29;
    const EINVALID_TIME_SETTINGS: u64 = 30;
    const EINVALID_INPUT: u64 = 31;
    const EINSUFFICIENT_TREASURY_BALANCE: u64 = 32;
    const EMULTISIG_THRESHOLD_NOT_MET: u64 = 33;

    // Constants
    const MAX_NAME_LENGTH: u64 = 50;
    const MAX_DESCRIPTION_LENGTH: u64 = 500;
    const MAX_URL_LENGTH: u64 = 100;
    const MAX_WHITELIST_BATCH: u64 = 1000;
    const MAX_ATTRIBUTE_KEY_LENGTH: u64 = 30;
    const MAX_ATTRIBUTE_VALUE_LENGTH: u64 = 50;
    const REVEAL_GRACE_PERIOD: u64 = 86400000; // 24 hours in milliseconds
    const MIN_ROYALTY_PERCENTAGE: u64 = 1;
    const MAX_ROYALTY_PERCENTAGE: u64 = 20;
    const DEFAULT_ADMIN_CAP_EXPIRY: u64 = 31536000000; // 1 year in milliseconds
    const ADMIN_CAP_EXPIRY_WARNING: u64 = 2592000000; // 30 days in milliseconds
    const ADMIN_CAP_GRACE_PERIOD: u64 = 604800000; // 7 days in milliseconds
    const DEFAULT_WITHDRAWAL_TIME_LOCK: u64 = 86400000; // 24 hours in milliseconds
    const MULTISIG_THRESHOLD: u64 = 2; // Number of signatures required for multi-sig operations

    // Role constants
    const ROLE_ADMIN: u64 = 1;
    const ROLE_MINTER: u64 = 2;
    const ROLE_WITHDRAWER: u64 = 4;

    // Structs
    struct NFT has key, store {
        id: UID,
        name: String,
        description: String,
        url: Url,
        creator: address,
        revealed: bool,
        reveal_time: u64,
        attributes: VecMap<String, String>,
    }

    struct Collection has key {
        id: UID,
        name: String,
        symbol: String,
        description: String,
        creator: address,
        royalty_percentage: u64,
        price: u64,
        minting_start: u64,
        minting_end: u64,
        reveal_time: u64,
        max_supply: u64,
        current_supply: u64,
        treasury: Balance<SUI>,
        paused: bool,
        whitelist: Table<address, u64>, // address -> expiry time
        upgradable: bool,
        reentrancy_guard: bool,
        version: u64,
        roles: Table<address, u64>, // address -> role bitmask
        pending_withdrawals: Table<address, PendingWithdrawal>,
        withdrawal_time_lock: u64,
        multisig_approvals: Table<address, vector<address>>, // operation hash -> approving addresses
    }

    struct AdminCap has key, store {
        id: UID,
        collection_id: UID,
        expiry: u64,
    }

    struct ReentrancyGuard<'a> {
        collection: &'a mut Collection
    }

    struct PendingWithdrawal has store {
        amount: u64,
        request_time: u64,
    }

    // Events
    struct NFTMinted has copy, drop {
        nft_id: address,
        creator: address,
        owner: address,
    }

    struct CollectionCreated has copy, drop {
        collection_id: address,
        name: String,
        creator: address,
        version: u64,
    }

    struct NFTRevealed has copy, drop {
        nft_id: address,
    }

    struct FundsWithdrawn has copy, drop {
        collection_id: address,
        amount: u64,
        recipient: address,
    }

    struct CollectionUpdated has copy, drop {
        collection_id: address,
        field: String,
        new_value: String,
    }

    struct WhitelistBatchUpdated has copy, drop {
        collection_id: address,
        operation: String, // "add" or "remove"
        count: u64,
        addresses: vector<address>,
    }

    struct AdminCapNearExpiry has copy, drop {
        collection_id: address,
        expiry: u64,
    }

    struct WithdrawalRequested has copy, drop {
        collection_id: address,
        amount: u64,
        requester: address,
        request_time: u64,
    }

    struct WithdrawalExecutionReady has copy, drop {
        collection_id: address,
        amount: u64,
        requester: address,
        execution_time: u64,
    }

    struct RoleUpdated has copy, drop {
        collection_id: address,
        user: address,
        new_role: u64,
    }

    struct MultiSigApprovalAdded has copy, drop {
        collection_id: address,
        operation_hash: address,
        approver: address,
    }

    // Functions

    public fun create_collection(
        name: vector<u8>,
        symbol: vector<u8>,
        description: vector<u8>,
        royalty_percentage: u64,
        price: u64,
        minting_start: u64,
        minting_end: u64,
        reveal_time: u64,
        max_supply: u64,
        upgradable: bool,
        admin_cap_expiry: Option<u64>,
        withdrawal_time_lock: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(royalty_percentage >= MIN_ROYALTY_PERCENTAGE && royalty_percentage <= MAX_ROYALTY_PERCENTAGE, EINVALID_ROYALTY_PERCENTAGE);
        assert!(is_valid_utf8(&name) && vector::length(&name) <= MAX_NAME_LENGTH, EINVALID_NAME_LENGTH);
        assert!(is_valid_utf8(&description) && vector::length(&description) <= MAX_DESCRIPTION_LENGTH, EINVALID_DESCRIPTION_LENGTH);
        assert!(minting_start < minting_end, EMINTING_START_AFTER_END);
        assert!(reveal_time >= minting_start, EREVEAL_TIME_BEFORE_START);
        assert!(reveal_time <= minting_end + REVEAL_GRACE_PERIOD, EREVEAL_TIME_AFTER_MINTING_END);

        let collection_id = object::new(ctx);
        let collection = Collection {
            id: collection_id,
            name: string::utf8(name),
            symbol: string::utf8(symbol),
            description: string::utf8(description),
            creator: tx_context::sender(ctx),
            royalty_percentage,
            price,
            minting_start,
            minting_end,
            reveal_time,
            max_supply,
            current_supply: 0,
            treasury: balance::zero(),
            paused: false,
            whitelist: table::new(ctx),
            upgradable,
            reentrancy_guard: false,
            version: 1,
            roles: table::new(ctx),
            pending_withdrawals: table::new(ctx),
            withdrawal_time_lock: option::get_with_default(&withdrawal_time_lock, DEFAULT_WITHDRAWAL_TIME_LOCK),
            multisig_approvals: table::new(ctx),
        };

        let current_time = clock::timestamp_ms(clock);
        let expiry = if (option::is_some(&admin_cap_expiry)) {
            let exp = option::extract(&mut admin_cap_expiry);
            assert!(exp > current_time, EINVALID_ADMIN_CAP_EXPIRY);
            exp
        } else {
            current_time + DEFAULT_ADMIN_CAP_EXPIRY
        };

        let admin_cap = AdminCap {
            id: object::new(ctx),
            collection_id: object::uid_to_inner(&collection.id),
            expiry,
        };

        // Set creator as admin with all roles
        table::add(&mut collection.roles, tx_context::sender(ctx), ROLE_ADMIN | ROLE_MINTER | ROLE_WITHDRAWER);

        event::emit(CollectionCreated {
            collection_id: object::uid_to_inner(&collection.id),
            name: collection.name,
            creator: collection.creator,
            version: collection.version,
        });

        transfer::share_object(collection);
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    public entry fun mint_nft(
        collection: &mut Collection,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        payment: &mut Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let guard = acquire_reentrancy_guard(collection);
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);

        assert!(has_role(collection, sender, ROLE_MINTER), EINSUFFICIENT_ROLE);
        assert!(!collection.paused, EMINTING_PAUSED);
        assert!(current_time >= collection.minting_start, EMINTING_NOT_STARTED);
        assert!(current_time <= collection.minting_end, EMINTING_ENDED);
        assert!(collection.current_supply < collection.max_supply, EMAX_SUPPLY_REACHED);
        
        assert!(is_address_whitelisted(collection, sender, current_time), ENOT_WHITELISTED);
        
        let payment_amount = coin::value(payment);
        assert!(payment_amount >= collection.price, EINSUFFICIENT_PAYMENT);

        assert!(is_valid_utf8(&name) && vector::length(&name) <= MAX_NAME_LENGTH, EINVALID_NAME_LENGTH);
        assert!(is_valid_utf8(&description) && vector::length(&description) <= MAX_DESCRIPTION_LENGTH, EINVALID_DESCRIPTION_LENGTH);
        assert!(is_valid_url(&url) && vector::length(&url) <= MAX_URL_LENGTH, EINVALID_URL_LENGTH);

        let nft = NFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe(string::utf8(url)),
            creator: collection.creator,
            revealed: false,
            reveal_time: collection.reveal_time,
            attributes: vec_map::empty(),
        };

        collection.current_supply = collection.current_supply + 1;

        let paid = coin::split(payment, collection.price, ctx);
        balance::join(&mut collection.treasury, coin::into_balance(paid));

        event::emit(NFTMinted {
            nft_id: object::uid_to_inner(&nft.id),
            creator: nft.creator,
            owner: sender,
        });

        transfer::transfer(nft, sender);
        drop(guard);
    }

    public entry fun reveal_nft(nft: &mut NFT, clock: &Clock, ctx: &TxContext) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= nft.reveal_time, ENOT_REVEALED);
        nft.revealed = true;

        event::emit(NFTRevealed {
            nft_id: object::uid_to_inner(&nft.id),
        });
    }

    public entry fun request_withdrawal(
        collection: &mut Collection,
        amount: u64,
        admin_cap: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let guard = acquire_reentrancy_guard(collection);
        let sender = tx_context::sender(ctx);
        assert!(object::uid_to_inner(&collection.id) == admin_cap.collection_id, ENOT_OWNER);
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= admin_cap.expiry, EADMIN_CAP_EXPIRED);
        assert!(has_role(collection, sender, ROLE_WITHDRAWER), EINSUFFICIENT_ROLE);
        assert!(amount > 0 && amount <= balance::value(&collection.treasury), EINVALID_WITHDRAW_AMOUNT);
        
        let pending_withdrawal = PendingWithdrawal {
            amount,
            request_time: current_time,
        };
        table::add(&mut collection.pending_withdrawals, sender, pending_withdrawal);

        event::emit(WithdrawalRequested {
            collection_id: object::uid_to_inner(&collection.id),
            amount,
            requester: sender,
            request_time: current_time,
        });

        check_admin_cap_expiry(admin_cap, current_time);
        drop(guard);
    }

    public entry fun execute_withdrawal(
        collection: &mut Collection,
        admin_cap: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let guard = acquire_reentrancy_guard(collection);
        let sender = tx_context::sender(ctx);
        assert!(object::uid_to_inner(&collection.id) == admin_cap.collection_id, ENOT_OWNER);
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= admin_cap.expiry, EADMIN_CAP_EXPIRED);
        assert!(has_role(collection, sender, ROLE_WITHDRAWER), EINSUFFICIENT_ROLE);
        
        assert!(table::contains(&collection.pending_withdrawals, sender), EINVALID_WITHDRAW_AMOUNT);
        let PendingWithdrawal { amount, request_time } = table::remove(&mut collection.pending_withdrawals, sender);
        assert!(current_time >= request_time + collection.withdrawal_time_lock, EWITHDRAWAL_TIME_LOCK_NOT_EXPIRED);
        
        // Multi-sig check
        let operation_hash = object::id_address(&admin_cap.id);
        if (!table::contains(&collection.multisig_approvals, operation_hash)) {
            table::add(&mut collection.multisig_approvals, operation_hash, vector::empty());
        };
        let approvals = table::borrow_mut(&mut collection.multisig_approvals, operation_hash);
        if (!vector::contains(approvals, &sender)) {
            vector::push_back(approvals, sender);
            event::emit(MultiSigApprovalAdded {
                collection_id: object::uid_to_inner(&collection.id),
                operation_hash,
                approver: sender,
            });
        };
        assert!(vector::length(approvals) >= MULTISIG_THRESHOLD, EMULTISIG_THRESHOLD_NOT_MET);

        assert!(balance::value(&collection.treasury) >= amount, EINSUFFICIENT_TREASURY_BALANCE);
        let funds = coin::take(&mut collection.treasury, amount, ctx);
        transfer::transfer(funds, sender);

        event::emit(FundsWithdrawn {
            collection_id: object::uid_to_inner(&collection.id),
            amount,
            recipient: sender,
        });

        check_admin_cap_expiry(admin_cap, current_time);
        drop(guard);
    }

    public entry fun update_collection(
        collection: &mut Collection,
        field: String,
        value: vector<u8>,
        admin_cap: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let guard = acquire_reentrancy_guard(collection);
        let sender = tx_context::sender(ctx);
        assert!(object::uid_to_inner(&collection.id) == admin_cap.collection_id, ENOT_OWNER);
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= admin_cap.expiry, EADMIN_CAP_EXPIRED);
        assert!(has_role(collection, sender, ROLE_ADMIN), EINSUFFICIENT_ROLE);
        assert!(collection.upgradable, EUPGRADE_NOT_ALLOWED);

        if (field == string::utf8(b"price")) {
            collection.price = option::extract(&mut option::some(sui::hex::decode(value)));
        } else if (field == string::utf8(b"minting_end")) {
            let new_end = option::extract(&mut option::some(sui::hex::decode(value)));
            assert!(new_end > collection.minting_start && new_end >= collection.reveal_time - REVEAL_GRACE_PERIOD, EINVALID_TIME_SETTINGS);
            collection.minting_end = new_end;
        } else if (field == string::utf8(b"paused")) {
            collection.paused = option::extract(&mut option::some(sui::hex::decode(value)));
        } else if (field == string::utf8(b"withdrawal_time_lock")) {
            let new_time_lock = option::extract(&mut option::some(sui::hex::decode(value)));
            assert!(new_time_lock > 0, EINVALID_WITHDRAWAL_TIME_LOCK);
            collection.withdrawal_time_lock = new_time_lock;
        } else {
            abort EINVALID_INPUT
        };

        collection.version = collection.version + 1;

        event::emit(CollectionUpdated {
            collection_id: object::uid_to_inner(&collection.id),
            field,
            new_value: string::utf8(value),
        });

        check_admin_cap_expiry(admin_cap, current_time);
        drop(guard);
    }

    public entry fun add_to_whitelist(
        collection: &mut Collection,
        addresses: vector<address>,
        expiry: u64,
        admin_cap: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let guard = acquire_reentrancy_guard(collection);
        let sender = tx_context::sender(ctx);
        assert!(object::uid_to_inner(&collection.id) == admin_cap.collection_id, ENOT_OWNER);
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= admin_cap.expiry, EADMIN_CAP_EXPIRED);
        assert!(has_role(collection, sender, ROLE_ADMIN), EINSUFFICIENT_ROLE);
        assert!(vector::length(&addresses) <= MAX_WHITELIST_BATCH, EBATCH_SIZE_EXCEEDED);

        let added_count = 0;
        let added_addresses = vector::empty<address>();
        while (!vector::is_empty(&addresses)) {
            let addr = vector::pop_back(&mut addresses);
            if (!table::contains(&collection.whitelist, addr)) {
                table::add(&mut collection.whitelist, addr, expiry);
                vector::push_back(&mut added_addresses, addr);
                added_count = added_count + 1;
            };
        };

        event::emit(WhitelistBatchUpdated {
            collection_id: object::uid_to_inner(&collection.id),
            operation: string::utf8(b"add"),
            count: added_count,
            addresses: added_addresses,
        });

        check_admin_cap_expiry(admin_cap, current_time);
        drop(guard);
    }

    public entry fun remove_from_whitelist(
        collection: &mut Collection,
        addresses: vector<address>,
        admin_cap: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let guard = acquire_reentrancy_guard(collection);
        let sender = tx_context::sender(ctx);
        assert!(object::uid_to_inner(&collection.id) == admin_cap.collection_id, ENOT_OWNER);
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= admin_cap.expiry, EADMIN_CAP_EXPIRED);
        assert!(has_role(collection, sender, ROLE_ADMIN), EINSUFFICIENT_ROLE);
        assert!(vector::length(&addresses) <= MAX_WHITELIST_BATCH, EBATCH_SIZE_EXCEEDED);

        let removed_count = 0;
        let removed_addresses = vector::empty<address>();
        while (!vector::is_empty(&addresses)) {
            let addr = vector::pop_back(&mut addresses);
            if (table::contains(&collection.whitelist, addr)) {
                table::remove(&mut collection.whitelist, addr);
                vector::push_back(&mut removed_addresses, addr);
                removed_count = removed_count + 1;
            };
        };

        event::emit(WhitelistBatchUpdated {
            collection_id: object::uid_to_inner(&collection.id),
            operation: string::utf8(b"remove"),
            count: removed_count,
            addresses: removed_addresses,
        });

        check_admin_cap_expiry(admin_cap, current_time);
        drop(guard);
    }

    public entry fun update_role(
        collection: &mut Collection,
        user: address,
        new_role: u64,
        admin_cap: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let guard = acquire_reentrancy_guard(collection);
        let sender = tx_context::sender(ctx);
        assert!(object::uid_to_inner(&collection.id) == admin_cap.collection_id, ENOT_OWNER);
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time <= admin_cap.expiry, EADMIN_CAP_EXPIRED);
        assert!(has_role(collection, sender, ROLE_ADMIN), EINSUFFICIENT_ROLE);
        assert!(is_valid_role(new_role), EINVALID_ROLE);

        if (table::contains(&collection.roles, user)) {
            table::remove(&mut collection.roles, user);
        };
        table::add(&mut collection.roles, user, new_role);

        event::emit(RoleUpdated {
            collection_id: object::uid_to_inner(&collection.id),
            user,
            new_role,
        });

        check_admin_cap_expiry(admin_cap, current_time);
        drop(guard);
    }

    // Helper functions

    fun acquire_reentrancy_guard(collection: &mut Collection): ReentrancyGuard {
        assert!(!collection.reentrancy_guard, EREENTRANCY);
        collection.reentrancy_guard = true;
        ReentrancyGuard { collection }
    }

    fun is_address_whitelisted(collection: &Collection, addr: address, current_time: u64): bool {
        if (table::is_empty(&collection.whitelist)) {
            true
        } else if (table::contains(&collection.whitelist, addr)) {
            let expiry = *table::borrow(&collection.whitelist, addr);
            current_time <= expiry
        } else {
            false
        }
    }

    fun check_admin_cap_expiry(admin_cap: &AdminCap, current_time: u64) {
        if (admin_cap.expiry - current_time <= ADMIN_CAP_EXPIRY_WARNING) {
            event::emit(AdminCapNearExpiry {
                collection_id: admin_cap.collection_id,
                expiry: admin_cap.expiry,
            });
        };
    }

    fun has_role(collection: &Collection, addr: address, role: u64): bool {
        if (table::contains(&collection.roles, addr)) {
            let user_role = *table::borrow(&collection.roles, addr);
            user_role & role != 0
        } else {
            false
        }
    }

    fun is_valid_role(role: u64): bool {
        role == ROLE_ADMIN || role == ROLE_MINTER || role == ROLE_WITHDRAWER ||
        role == (ROLE_ADMIN | ROLE_MINTER) || role == (ROLE_ADMIN | ROLE_WITHDRAWER) ||
        role == (ROLE_MINTER | ROLE_WITHDRAWER) || role == (ROLE_ADMIN | ROLE_MINTER | ROLE_WITHDRAWER)
    }

    fun is_valid_utf8(input: &vector<u8>): bool {
        // This is a simplified UTF-8 validation.
        // In practice, you'd want a more comprehensive check.
        let i = 0;
        let len = vector::length(input);
        while (i < len) {
            let byte = *vector::borrow(input, i);
            if (byte > 0x7F) {
                return false
            };
            i = i + 1;
        };
        true
    }

    fun is_valid_url(url: &vector<u8>): bool {
        // This is a simplified URL validation.
        // In practice, you'd want a more comprehensive check.
        let s = string::utf8(*url);
        string::index_of(&s, &string::utf8(b"http://")) == 0 || 
        string::index_of(&s, &string::utf8(b"https://")) == 0
    }

    // Implement Drop for ReentrancyGuard
    fun drop(guard: ReentrancyGuard) {
        let ReentrancyGuard { collection } = guard;
        collection.reentrancy_guard = false;
    }

    // Additional helper functions for improved functionality

    public fun get_price(collection: &Collection): u64 {
        collection.price
    }

    public fun get_treasury_balance(collection: &Collection): u64 {
        balance::value(&collection.treasury)
    }

    // Function to check if the admin cap is in the grace period
    fun is_admin_cap_in_grace_period(admin_cap: &AdminCap, current_time: u64): bool {
        current_time > admin_cap.expiry && current_time <= admin_cap.expiry + ADMIN_CAP_GRACE_PERIOD
    }

    // Function to extend admin cap expiry
    public entry fun extend_admin_cap_expiry(
        collection: &mut Collection,
        admin_cap: &mut AdminCap,
        new_expiry: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        assert!(has_role(collection, sender, ROLE_ADMIN), EINSUFFICIENT_ROLE);
        assert!(new_expiry > current_time, EINVALID_ADMIN_CAP_EXPIRY);
        assert!(is_admin_cap_in_grace_period(admin_cap, current_time), EADMIN_CAP_IN_GRACE_PERIOD);

        admin_cap.expiry = new_expiry;

        event::emit(AdminCapNearExpiry {
            collection_id: admin_cap.collection_id,
            expiry: new_expiry,
        });
    }

    // Function to implement a fail-safe mechanism
    public entry fun trigger_fail_safe(
        collection: &mut Collection,
        admin_cap: &AdminCap,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);
        let current_time = clock::timestamp_ms(clock);
        assert!(object::uid_to_inner(&collection.id) == admin_cap.collection_id, ENOT_OWNER);
        assert!(current_time <= admin_cap.expiry, EADMIN_CAP_EXPIRED);
        assert!(has_role(collection, sender, ROLE_ADMIN), EINSUFFICIENT_ROLE);

        // Implement fail-safe logic here
        // For example, pause all contract functions
        collection.paused = true;

        event::emit(CollectionUpdated {
            collection_id: object::uid_to_inner(&collection.id),
            field: string::utf8(b"paused"),
            new_value: string::utf8(b"true"),
        });
    }

    #[test_only]
    module nft_collection::collection_tests {
        use sui::test_scenario::{Self, Scenario};
        use sui::clock::{Self, Clock};
        use sui::coin::{Self, Coin};
        use sui::sui::SUI;
        use nft_collection::collection::{Self, Collection, AdminCap, NFT};
        use std::string;
        use std::vector;

        // Test helper function to create a collection
        fun create_test_collection(scenario: &mut Scenario, clock: &mut Clock) {
            let ctx = test_scenario::ctx(scenario);
            collection::create_collection(
                b"Test Collection",
                b"TEST",
                b"A test collection",
                5, // 5% royalty
                1000000, // 1 SUI
                clock::timestamp_ms(clock), // minting starts now
                clock::timestamp_ms(clock) + 1000000000, // minting ends in the future
                clock::timestamp_ms(clock) + 500000000, // reveal time
                1000, // max supply
                true, // upgradable
                std::option::none(), // use default admin cap expiry
                std::option::none(), // use default withdrawal time lock
                clock,
                ctx
            );
        }

        #[test]
        fun test_create_collection() {
            let scenario = test_scenario::begin(@0x1);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            create_test_collection(&mut scenario, &mut clock);

            test_scenario::next_tx(&mut scenario, @0x1);

            // Check if the collection was created
            assert!(test_scenario::has_most_recent_shared<Collection>(), 0);
            assert!(test_scenario::has_most_recent_for_address<AdminCap>(@0x1), 0);

            clock::destroy_for_testing(clock);
            test_scenario::end(scenario);
        }

        #[test]
        fun test_mint_nft() {
            let scenario = test_scenario::begin(@0x1);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            create_test_collection(&mut scenario, &mut clock);

            test_scenario::next_tx(&mut scenario, @0x1);

            // Mint an NFT
            let collection = test_scenario::take_shared<Collection>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1000000, test_scenario::ctx(&mut scenario));
            
            collection::mint_nft(
                &mut collection,
                b"Test NFT",
                b"A test NFT",
                b"https://test.com/nft",
                &mut payment,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            test_scenario::return_shared(collection);
            coin::burn_for_testing(payment);

            test_scenario::next_tx(&mut scenario, @0x1);

            // Check if the NFT was minted
            assert!(test_scenario::has_most_recent_for_address<NFT>(@0x1), 0);

            clock::destroy_for_testing(clock);
            test_scenario::end(scenario);
        }

        #[test]
        fun test_whitelist_operations() {
            let scenario = test_scenario::begin(@0x1);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            create_test_collection(&mut scenario, &mut clock);

            test_scenario::next_tx(&mut scenario, @0x1);

            let collection = test_scenario::take_shared<Collection>(&scenario);
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, @0x1);

            // Add to whitelist
            let addresses = vector::empty<address>();
            vector::push_back(&mut addresses, @0x2);
            vector::push_back(&mut addresses, @0x3);

            collection::add_to_whitelist(
                &mut collection,
                addresses,
                clock::timestamp_ms(&clock) + 1000000, // expiry in the future
                &admin_cap,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            // Check if addresses are whitelisted
            assert!(collection::is_address_whitelisted(&collection, @0x2, clock::timestamp_ms(&clock)), 0);
            assert!(collection::is_address_whitelisted(&collection, @0x3, clock::timestamp_ms(&clock)), 0);

            // Remove from whitelist
            let remove_addresses = vector::empty<address>();
            vector::push_back(&mut remove_addresses, @0x2);

            collection::remove_from_whitelist(
                &mut collection,
                remove_addresses,
                &admin_cap,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            // Check if address was removed from whitelist
            assert!(!collection::is_address_whitelisted(&collection, @0x2, clock::timestamp_ms(&clock)), 0);
            assert!(collection::is_address_whitelisted(&collection, @0x3, clock::timestamp_ms(&clock)), 0);

            test_scenario::return_shared(collection);
            test_scenario::return_to_address(@0x1, admin_cap);

            clock::destroy_for_testing(clock);
            test_scenario::end(scenario);
        }

        #[test]
        fun test_update_collection() {
            let scenario = test_scenario::begin(@0x1);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            create_test_collection(&mut scenario, &mut clock);

            test_scenario::next_tx(&mut scenario, @0x1);

            let collection = test_scenario::take_shared<Collection>(&scenario);
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, @0x1);

            // Update collection price
            collection::update_collection(
                &mut collection,
                string::utf8(b"price"),
                b"2000000", // New price: 2 SUI
                &admin_cap,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            // Check if price was updated
            assert!(collection::get_price(&collection) == 2000000, 0);

            test_scenario::return_shared(collection);
            test_scenario::return_to_address(@0x1, admin_cap);

            clock::destroy_for_testing(clock);
            test_scenario::end(scenario);
        }

        #[test]
        fun test_withdrawal_process() {
            let scenario = test_scenario::begin(@0x1);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            create_test_collection(&mut scenario, &mut clock);

            test_scenario::next_tx(&mut scenario, @0x1);

            let collection = test_scenario::take_shared<Collection>(&scenario);
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, @0x1);

            // Mint an NFT to add funds to the collection
            let payment = coin::mint_for_testing<SUI>(1000000, test_scenario::ctx(&mut scenario));
            collection::mint_nft(
                &mut collection,
                b"Test NFT",
                b"A test NFT",
                b"https://test.com/nft",
                &mut payment,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            coin::burn_for_testing(payment);

            // Request withdrawal
            collection::request_withdrawal(
                &mut collection,
                500000, // Withdraw 0.5 SUI
                &admin_cap,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            // Advance clock to pass the withdrawal time lock
            clock::set_for_testing(&mut clock, clock::timestamp_ms(&clock) + collection::DEFAULT_WITHDRAWAL_TIME_LOCK + 1);

            // Execute withdrawal
            collection::execute_withdrawal(
                &mut collection,
                &admin_cap,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            // Check if funds were withdrawn
            assert!(collection::get_treasury_balance(&collection) == 500000, 0);

            test_scenario::return_shared(collection);
            test_scenario::return_to_address(@0x1, admin_cap);

            clock::destroy_for_testing(clock);
            test_scenario::end(scenario);
        }

        #[test]
        #[expected_failure(abort_code = collection::EINSUFFICIENT_ROLE)]
        fun test_unauthorized_mint() {
            let scenario = test_scenario::begin(@0x1);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            create_test_collection(&mut scenario, &mut clock);

            test_scenario::next_tx(&mut scenario, @0x2);

            let collection = test_scenario::take_shared<Collection>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1000000, test_scenario::ctx(&mut scenario));
            
            // This should fail because @0x2 doesn't have the MINTER role
            collection::mint_nft(
                &mut collection,
                b"Test NFT",
                b"A test NFT",
                b"https://test.com/nft",
                &mut payment,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            test_scenario::return_shared(collection);
            coin::burn_for_testing(payment);

            clock::destroy_for_testing(clock);
            test_scenario::end(scenario);
        }

        #[test]
        fun test_admin_cap_expiry() {
            let scenario = test_scenario::begin(@0x1);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            create_test_collection(&mut scenario, &mut clock);

            test_scenario::next_tx(&mut scenario, @0x1);

            let collection = test_scenario::take_shared<Collection>(&scenario);
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, @0x1);

            // Advance clock to near admin cap expiry
            clock::set_for_testing(&mut clock, admin_cap.expiry - collection::ADMIN_CAP_EXPIRY_WARNING + 1);

            // Attempt to update collection (should emit warning)
            collection::update_collection(
                &mut collection,
                string::utf8(b"price"),
                b"2000000",
                &admin_cap,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            // Advance clock past admin cap expiry
            clock::set_for_testing(&mut clock, admin_cap.expiry + 1);

            // Attempt to extend admin cap expiry
            collection::extend_admin_cap_expiry(
                &mut collection,
                &mut admin_cap,
                clock::timestamp_ms(&clock) + collection::DEFAULT_ADMIN_CAP_EXPIRY,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            // Check if admin cap expiry was extended
            assert!(admin_cap.expiry > clock::timestamp_ms(&clock), 0);

            test_scenario::return_shared(collection);
            test_scenario::return_to_address(@0x1, admin_cap);

            clock::destroy_for_testing(clock);
            test_scenario::end(scenario);
        }

        #[test]
        fun test_fail_safe_mechanism() {
            let scenario = test_scenario::begin(@0x1);
            let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

            create_test_collection(&mut scenario, &mut clock);

            test_scenario::next_tx(&mut scenario, @0x1);

            let collection = test_scenario::take_shared<Collection>(&scenario);
            let admin_cap = test_scenario::take_from_address<AdminCap>(&scenario, @0x1);

            // Trigger fail-safe mechanism
            collection::trigger_fail_safe(
                &mut collection,
                &admin_cap,
                &clock,
                test_scenario::ctx(&mut scenario)
            );

            // Check if collection is paused
            assert!(collection.paused, 0);

            test_scenario::return_shared(collection);
            test_scenario::return_to_address(@0x1, admin_cap);

            clock::destroy_for_testing(clock);
            test_scenario::end(scenario);
        }

        // TO-DO: Add more test functions...
    }
}
