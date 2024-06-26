import { TransactionBlock } from '@mysten/sui.js/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { packageId, Kiosk, nftId } from '../utils/packageInfo';
dotenv.config();


async function requestApprove() {
    const { keypair, client } = getExecStuff();
    const tx = new TransactionBlock();
    tx.moveCall({
        target: `${packageId}::kiosk::request_approve_for_list`,
        arguments: [
            tx.object(Kiosk),
            tx.object(nftId),
            tx.pure.u64(10000000),
        ],
        typeArguments: [`${packageId}::nft::NFT`]

    });

    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx,
    });
    console.log({ result });
}


requestApprove();
