import { TransactionBlock } from '@mysten/sui.js/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { packageId, Kiosk, nftId, TransferPolicyId } from '../utils/packageInfo';
dotenv.config();

async function purchase() {
    const { keypair, client } = getExecStuff();
    const tx = new TransactionBlock();
    const coin = tx.splitCoins(tx.gas, [tx.pure(20000000)]);
    const coin2 = tx.splitCoins(tx.gas, [tx.pure(100000)]);
    const itemType = `${packageId}::nft::NFT`;

    const nested_result = tx.moveCall({
        target: `${packageId}::kiosk::purchase`,
        arguments: [
            tx.object(Kiosk),
            tx.pure.address(nftId),
            tx.object(coin),
        ],
        typeArguments: [itemType]
    });

    console.log("Bought from kiosk")

    tx.moveCall({
        target: `${packageId}::royalty_policy::pay`,
        arguments: [
            tx.object(TransferPolicyId),
            nested_result[1],
            tx.object(coin2),
        ],
        typeArguments: [itemType]
    });

    // confirm the request
    tx.moveCall({
        target: `0x02::transfer_policy::confirm_request`,
        arguments: [
            tx.object(TransferPolicyId),
            nested_result[1],
        ],
        typeArguments: [itemType]
    });

    tx.moveCall({
        target: `0x02::transfer::public_transfer`,
        arguments: [
            nested_result[0],
            tx.pure.address("0x16b80901b9e6d3c8b5f54dc8a414bb1a75067db897e7a3624793176b97445ec6"),
        ],
        typeArguments: [itemType]
    });

    tx.transferObjects([coin2], "0x16b80901b9e6d3c8b5f54dc8a414bb1a75067db897e7a3624793176b97445ec6");

    const result = await client.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        signer: keypair,
    });
    console.log(result)
}

purchase();
