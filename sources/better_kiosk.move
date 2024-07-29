/// @title Better Kiosk
/// @author Spooderman
/// @notice Kiosk but with a slight twist to make it more better.

module better_kiosk::kiosk {
        use sui::dynamic_field as df;
    use sui::transfer_policy::{
        Self,
        TransferRequest
    };
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::event;

    /*//////////////////////////////////////////////////////////////////////////
                                     ERRORS
    ////////////////////////////////////////////////////////////////////////// */

    const ENotOwner: u64 = 1;
    const EItemNotFound: u64 = 2;
    const ENftPriceLess: u64 = 3;
    const EIncorrectAmount: u64 = 4;
    const ENotEnough: u64 = 5;
    const ENotEmpty: u64 = 6;

    /*//////////////////////////////////////////////////////////////////////////
                                     Structs
    ////////////////////////////////////////////////////////////////////////// */
    
    /// @dev An object which allows selling collectibles within "kiosk" ecosystem.

    public struct Kiosk has key, store {
        id: UID,
        profits: Balance<SUI>,
        owner: address,
        item_count: u32,
        nft_owner: Table<ID, address>,
        prices: Table<ID, u64>,
    }

    /// @dev A Capability granting the bearer a right to `approve` requested nft and `take` profit from kiosk.

    public struct KioskOwnerCap has key, store {
        id: UID,
        `for`: ID
    }

    /// @dev Dynamic field key for an item placed into the kiosk.
    
    public struct Item has store, copy, drop { id: ID }

    /// @dev Dynamic field key for an active offer to purchase the T.
    
    public struct Listing has store, copy, drop { id: ID}

    /*//////////////////////////////////////////////////////////////////////////
                                     Events
    ////////////////////////////////////////////////////////////////////////// */

    public struct ItemRequested<phantom T: key + store> has copy, drop {
        kiosk: ID,
        id: ID,
        price: u64
    }

    public struct ItemPurchased<phantom T: key + store> has copy, drop {
        kiosk: ID,
        id: ID,
        price: u64
    }

    public struct ItemWithdrawn<phantom T: key + store> has copy, drop {
        kiosk: ID,
        id: ID
    }

    public struct ItemReturned<phantom T: key + store> has copy, drop {
        kiosk: ID,
        id: ID
    }

    public struct ItemListed<phantom T: key + store> has copy, drop {
        kiosk: ID,
        id: ID,
        price: u64
    }

    public struct OwnerChanged has copy, drop {
        prev_owner: address,
        new_owner: address
    }


    /*//////////////////////////////////////////////////////////////////////////
                                     Kiosk Creation
    ////////////////////////////////////////////////////////////////////////// */

    /// @dev Creates a new Kiosk in a default configuration: sender receives the`KioskOwnerCap` and becomes the Owner, the `Kiosk` is shared.
    
    #[allow(lint(self_transfer, share_owned))]
    entry fun default(ctx: &mut TxContext) {
        let (kiosk, cap) = new(ctx);
        sui::transfer::transfer(cap, ctx.sender());
        sui::transfer::share_object(kiosk);
    }

    /// @dev Creates a new `Kiosk` with a matching `KioskOwnerCap`.

    public fun new(ctx: &mut TxContext): (Kiosk, KioskOwnerCap) {
        let kiosk = Kiosk {
            id: object::new(ctx),
            profits: balance::zero(),
            owner: ctx.sender(),
            item_count: 0,
            nft_owner: table::new(ctx),
            prices: table::new(ctx),
        };

        let cap = KioskOwnerCap {
            id: object::new(ctx),
            `for`: object::id(&kiosk)
        };

        (kiosk, cap)
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     User Functionality
    ////////////////////////////////////////////////////////////////////////// */
    
    /**
    * @dev Allows an item owner to submit a request for approval to list their NFT for sale on the Kiosk.
    * @param self Reference to the Kiosk where the owner wants to list the item.
    * @param item An item the owner wants to list.
    * @param price The desired selling price for the NFT in the Kiosk.
    */

    public fun list_request<T: key + store>(
        self: &mut Kiosk, 
        item: T,
        price: u64,
        ctx: &mut TxContext,
    ) {
        event::emit(ItemRequested<T> { kiosk: object::id(self), id: object::id(&item), price });
        self.place_internal(item, price, ctx); 
    }

    /**
    * @dev Allows the NFT owner to cancel a listing request or withdraw from a purchase in progress.
    * @param self Reference to the Kiosk where the owner wants to list the item.
    * @param id The unique identifier of the NFT in question.
    */

    public fun withdraw_nft<T: key + store>(
        self: &mut Kiosk, id: ID, ctx: &TxContext
    ){
        assert!(self.has_item(id), EItemNotFound);
        assert!(self.is_owner(id, ctx), ENotOwner);
        // if approved for purchase
        if (self.is_listed(id)){
              df::remove_if_exists<Listing, u64>(&mut self.id, Listing { id});  
        };
        let inner = df::remove<Item, T>(&mut self.id, Item { id}); 
        self.item_count = self.item_count - 1;
        let nft_owner = table::borrow(&self.nft_owner, id);
        sui::transfer::public_transfer(inner, *nft_owner); 
        table::remove(&mut self.nft_owner, id); 
        table::remove(&mut self.prices, id); 
        event::emit(ItemWithdrawn<T> { kiosk: object::id(self), id});  
    }

    /**
    * @dev Allows a user to purchase an Item listed on the Kiosk.
    * @param self Reference to the Kiosk where the owner wants to purchase the item.
    * @param id The unique identifier of the NFT to purchase.
    * @param payment The exact amount of SUI coins required for the purchase.
    */

    public fun purchase<T: key + store>(
        self: &mut Kiosk, id: ID, payment: Coin<SUI>, ctx: &mut TxContext
    ): (T, TransferRequest<T>) {
        let price = df::remove<Listing, u64>(&mut self.id, Listing { id});
        let inner = df::remove<Item, T>(&mut self.id, Item { id });

        self.item_count = self.item_count - 1;
        assert!(price == payment.value(), EIncorrectAmount);
        df::remove_if_exists<Listing, bool>(&mut self.id, Listing { id });
        let item_owner: &address = table::borrow(&self.nft_owner, id);
        let original_price = table::borrow(&self.prices, id);
        let mut balance = coin::into_balance(payment);
        if (price > *original_price){ 
            let profit_coin = coin::take(&mut balance, price - *original_price, ctx);
            coin::put(&mut self.profits, profit_coin);
        };
        let payment = coin::from_balance(balance, ctx);
        transfer::public_transfer(payment, *item_owner);
        event::emit(ItemPurchased<T> { kiosk: object::id(self), id, price });
        (inner, transfer_policy::new_request(id, price, object::id(self)))
    }


    /*//////////////////////////////////////////////////////////////////////////
                                     Admin Functionality
    ////////////////////////////////////////////////////////////////////////// */

    
    /**
    * @dev Allows the Kiosk owner to review and finalize listing requests for Items.
    * @param self Reference to the Kiosk where the owner wants to list the item.
    * @param cap Capability object for Kiosk owner authorization.
    * @param id The unique identifier of the NFT request.
    * @param new_price (Optional) The desired selling price for the NFT (must be greater than the initial request).
    * @param list_in_marketplace Indicates whether to list the NFT or return it to the owner.
    */

    public fun finalize_listing<T: key + store>(
        self: &mut Kiosk, cap: &KioskOwnerCap, id: ID, new_price: u64, list_in_marketplace: bool,
    ){
        assert!(self.has_access(cap), ENotOwner);
        assert!(self.has_item(id), EItemNotFound);
        if (!list_in_marketplace){
            self.item_count = self.item_count - 1;
            let inner = df::remove<Item, T>(&mut self.id, Item { id}); 
            let nft_owner = table::borrow(&self.nft_owner, id);
            event::emit(ItemReturned<T> { kiosk: object::id(self), id});
            sui::transfer::public_transfer(inner, *nft_owner);        
        }else{
            assert!(self.has_item_with_type<T>(id), EItemNotFound);
            let price = *table::borrow(&self.prices, id);
            assert!(new_price >= price, ENftPriceLess);
            event::emit(ItemListed<T> { kiosk: object::id(self), id, price });
            df::add(&mut self.id, Listing { id}, new_price);
        };
    }
    
    /**
    * @dev Allows the Kiosk owner to withdraw profits accumulated from sales.
    * @param self Reference to the Kiosk.
    * @param cap Capability object for Kiosk owner authorization.
    * @param amount (Optional) The specific amount of SUI coins to withdraw.
        * If omitted, withdraws all available profits.
    */

    public fun withdraw_profit(
        self: &mut Kiosk, cap: &KioskOwnerCap, amount: Option<u64>, ctx: &mut TxContext
    ): Coin<SUI> {
        assert!(self.has_access(cap), ENotOwner);

        let amount = if (amount.is_some()) {
            let amt = amount.destroy_some();
            assert!(amt <= self.profits.value(), ENotEnough);
            amt
        } else {
            self.profits.value()
        };

        coin::take(&mut self.profits, amount, ctx)
    }

    /**
    * @dev Allows the current Kiosk owner to transfer ownership to a new address.
    * @param self Reference to the Kiosk.
    * @param cap Capability object for Kiosk owner authorization.
    * @param owner The address of the new Kiosk owner.
    */

    public fun set_owner_custom(
        self: &mut Kiosk, cap: &KioskOwnerCap, owner: address, ctx: &TxContext
    ) {
        assert!(self.has_access(cap), ENotOwner);
        event::emit(OwnerChanged { prev_owner: ctx.sender(), new_owner: owner });
        self.owner = owner
    }

    /**
    * @dev Allows the Kiosk owner to permanently close the Kiosk and withdraw any remaining profits.
    * @param self Immutable reference to the Kiosk contract (used for destructuring).
    * @param cap Capability object for Kiosk owner authorization.
    *
    * **Important Note:** This function permanently closes the Kiosk and cannot be undone.
    * 
    * @return The total amount of SUI coins withdrawn from the Kiosk's profits.
    */

    public fun close_and_withdraw_profit(
        self: Kiosk, cap: KioskOwnerCap, ctx: &mut TxContext
    ): Coin<SUI> {
        let Kiosk { id, profits, owner: _, item_count, nft_owner, prices } = self;
        let KioskOwnerCap { id: cap_id, `for` } = cap;

        assert!(id.to_inner() == `for`, ENotOwner);
        assert!(item_count == 0, ENotEmpty);

        cap_id.delete();
        id.delete();
        table::drop(nft_owner);
        table::drop(prices);

        profits.into_coin(ctx)
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     View Functions
    ////////////////////////////////////////////////////////////////////////// */
    
    /**
    * @dev Checks if a specific item exists in the Kiosk based on its unique identifier.
    * @param self Reference to the Kiosk.
    * @param id The unique identifier of the item to be checked.
    * @return True if the item exists in the Kiosk, false otherwise.
    */
    
    public fun has_item(self: &Kiosk, id: ID): bool {
        df::exists_(&self.id, Item { id })
    }

    /**
    * @dev Verifies if the provided capability object grants access for modifying the Kiosk.
    * @param self Reference to the Kiosk.
    * @param cap Capability object for Kiosk owner authorization.
    * @return True if the capability grants access, false otherwise.
    */

    public fun has_access(self: &mut Kiosk, cap: &KioskOwnerCap): bool {
        object::id(self) == cap.`for`
    }

    /**
    * @dev Checks if a specific item with a given type exists in the Kiosk based on its identifier.
    * @param self Reference to the Kiosk.
    * @param id The unique identifier of the item to be checked.
    * @return True if the item exists and has the specified type, false otherwise.
    */

    public fun has_item_with_type<T: key + store>(self: &Kiosk, id: ID): bool {
        df::exists_with_type<Item, T>(&self.id, Item { id })
    }

    /**
    * @dev Checks if a specific item is currently listed for sale on the Kiosk marketplace.
    * @param self Reference to the Kiosk.
    * @param id The unique identifier of the item to be checked.
    * @return True if the item is listed for sale, false otherwise.
    */

    public fun is_listed(self: &Kiosk, id: ID): bool {
        df::exists_(&self.id, Listing { id})
    }

    /**
    * @dev Verifies if the message sender is the owner of the NFT associated with a specific item.
    * @param self Reference to the Kiosk.
    * @param id The unique identifier of the item to be checked.
    * @return True if the message sender is the owner of the NFT, false otherwise.
    */

    public fun is_owner(self: &Kiosk, id: ID, ctx: &TxContext): bool {
        let nft_owner = table::borrow(&self.nft_owner, id);
        let caller = tx_context::sender(ctx);
        if (caller == nft_owner){
            true
        }else{
            false
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     Private Function
    ////////////////////////////////////////////////////////////////////////// */
    
    /**
    * @dev Internal function for adding a new item listing to the Kiosk (not directly callable).
    * @param self Reference to the Kiosk.
    * @param item The NFT object to be listed.
    * @param price The desired selling price for the NFT.
    */

    public(package) fun place_internal<T: key + store>(self: &mut Kiosk, item: T, price: u64, ctx: &TxContext) {
        let nft_owner = tx_context::sender(ctx);
        self.item_count = self.item_count + 1;
        let item_id = object::id(&item);
        df::add(&mut self.id, Item { id: item_id }, item);
        table::add(&mut self.nft_owner, item_id, nft_owner);
        table::add(&mut self.prices, item_id, price);
    }
}