module better_kiosk::kiosk {
    use sui::dynamic_object_field as dof;
    use sui::dynamic_field as df;
    use sui::transfer_policy::{
        Self,
        TransferPolicy,
        TransferRequest
    };
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::event;
    use sui::table::{Self, Table};

    const ENotOwner: u64 = 0;
    const EItemNotFound: u64 = 11;
    const ENftPriceLess: u64 = 12;

    public struct Kiosk has key, store {
        id: UID,
        profits: Balance<SUI>,
        owner: address,
        item_count: u32,
        nft_owner: Table<ID, address>,
        fee_on_list: bool,
        prices: Table<ID, u64>,
    }

    public struct KioskOwnerCap has key, store {
        id: UID,
        `for`: ID
    }

    public struct Item has store, copy, drop { id: ID }

    public struct Listing has store, copy, drop { id: ID}

    #[allow(lint(self_transfer, share_owned))]
    entry fun default(ctx: &mut TxContext) {
        let (kiosk, cap) = new(ctx);
        sui::transfer::transfer(cap, ctx.sender());
        sui::transfer::share_object(kiosk);
    }

    public fun new(ctx: &mut TxContext): (Kiosk, KioskOwnerCap) {
        let kiosk = Kiosk {
            id: object::new(ctx),
            profits: balance::zero(),
            owner: ctx.sender(),
            item_count: 0,
            nft_owner: table::new(ctx),
            fee_on_list: false,
            prices: table::new(ctx),
        };

        let cap = KioskOwnerCap {
            id: object::new(ctx),
            `for`: object::id(&kiosk)
        };

        (kiosk, cap)
    }

    public fun request_approve_for_list<T: key + store>(
        self: &mut Kiosk, item: T,
        price: u64,
        ctx: &mut TxContext,
    ) {
        self.place_internal(item, price, ctx)
    }

    public(package) fun place_internal<T: key + store>(self: &mut Kiosk, item: T, price: u64, ctx: &TxContext) {
        let nft_owner = tx_context::sender(ctx);
        self.item_count = self.item_count + 1;
        let item_id = object::id(&item);
        dof::add(&mut self.id, Item { id: item_id }, item);
        table::add(&mut self.nft_owner, item_id, nft_owner);
        table::add(&mut self.prices, item_id, price);
    }

    // either make nft for available to purchase or remove from listing and send back to the original owner
    public fun fullfill_request_for_nft<T: key + store>(
        self: &mut Kiosk, cap: &KioskOwnerCap, id: ID, new_price: u64, list_in_marketplace: bool,
    ){
        assert!(self.has_access(cap), ENotOwner);
        assert!(self.has_item(id), EItemNotFound);
        if (!list_in_marketplace){
            self.item_count = self.item_count - 1;
            df::remove_if_exists<Listing, u64>(&mut self.id, Listing { id});
            let nft_owner = table::borrow(&self.nft_owner, id);
            sui::transfer::public_transfer(dof::remove<ID, T>(&mut self.id, id), *nft_owner);        
        }else{
            assert!(self.has_item_with_type<T>(id), EItemNotFound);
            let price = *table::borrow(&self.prices, id);
            assert!(new_price > price, ENftPriceLess);
            df::add(&mut self.id, Listing { id}, new_price);
        };
    }

    public fun has_item(self: &Kiosk, id: ID): bool {
        dof::exists_(&self.id, Item { id })
    }

    public fun has_access(self: &mut Kiosk, cap: &KioskOwnerCap): bool {
        object::id(self) == cap.`for`
    }

    public fun has_item_with_type<T: key + store>(self: &Kiosk, id: ID): bool {
        dof::exists_with_type<Item, T>(&self.id, Item { id })
    }

    public fun is_owner(self: &Kiosk, id: ID, ctx: &TxContext): bool {
        let nft_owner = table::borrow(&self.nft_owner, id);
        let caller = tx_context::sender(ctx);
        if (caller == nft_owner){
            true
        }else{
            false
        }
    }

    // allowing nft_owner to cancel from listing or making withdrawl from purchase
    public fun remove_listing_or_withdraw_from_purchase<T: key + store>(
        self: &mut Kiosk, id: ID, ctx: &TxContext
    ){
        assert!(self.has_item(id), EItemNotFound);
        assert!(self.is_owner(id, ctx), ENotOwner);
        // if only listed
        if (self.has_item(id)){
            df::remove_if_exists<Item, u64>(&mut self.id, Item { id});     
        }
        // if approved for purchase
        else{
            df::remove_if_exists<Listing, u64>(&mut self.id, Listing { id});
        };
        self.item_count = self.item_count - 1;
        let nft_owner = table::borrow(&self.nft_owner, id);
        sui::transfer::public_transfer(dof::remove<ID, T>(&mut self.id, id), *nft_owner); 
        table::remove(&mut self.nft_owner, id); 
        table::remove(&mut self.prices, id);   
    }
}