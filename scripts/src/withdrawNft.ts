import { TransactionBlock } from '@mysten/sui.js/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { packageId, Kiosk, nftId } from '../utils/packageInfo';
dotenv.config();


async function withdrawNft() {
    const { keypair, client } = getExecStuff();
    const tx = new TransactionBlock();
    tx.moveCall({
        target: `${packageId}::kiosk::withdraw_nft`,
        arguments: [
            tx.object(Kiosk),
            tx.pure.address(nftId),
        ],
        typeArguments: [`${packageId}::nft::NFT`]
    });

    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx,
    });
    console.log({ result });
}


withdrawNft();
