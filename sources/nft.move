module better_kiosk::nft { 
    use std::string;

    public struct NFT has key, store { 
        id: UID, 
        n: u64, 
        url: string::String
    }

    public struct NftCap has key { 
        id: UID, 
        issued_counter: u64
    }

    fun init(ctx: &mut TxContext) { 
        let minting_cap = NftCap { 
            id: object::new(ctx), 
            issued_counter: 0, 
        }; 
        transfer::transfer(minting_cap, tx_context::sender(ctx));
    }

    public entry fun mint(cap: &mut NftCap, url: string::String, receiver: address, ctx: &mut TxContext) {
        let n = cap.issued_counter; 
        cap.issued_counter = n + 1; 
        let nft = NFT { 
            id: object::new(ctx), 
            n: n, 
            url: url 
        }; 
        transfer::transfer(nft, receiver); 
    } 
}