import { TransactionBlock } from '@mysten/sui.js/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { packageId, Kiosk, nftId, KioskOwnerCap } from '../utils/packageInfo';
dotenv.config();


async function finalizeListing() {
    const { keypair, client } = getExecStuff();
    const tx = new TransactionBlock();
    tx.moveCall({
        target: `${packageId}::kiosk::finalize_listing`,
        arguments: [
            tx.object(Kiosk),
            tx.object(KioskOwnerCap),
            tx.pure.address(nftId),
            tx.pure.u64(20000000),
            tx.pure.bool(true),
        ],
        typeArguments: [`${packageId}::nft::NFT`]

    });

    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx,
    });
    console.log({ result });
}


finalizeListing();
