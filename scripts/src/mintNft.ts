import { TransactionBlock } from '@mysten/sui.js/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { packageId, nftCap } from '../utils/packageInfo';
dotenv.config();


async function mintNft() {
    const { keypair, client } = getExecStuff();
    const tx = new TransactionBlock();
    tx.moveCall({
        target: `${packageId}::nft::mint`,
        arguments: [
            tx.object(nftCap),
            tx.pure.string("https://pab5t5ilizasxkoexee3olx3jmhkm4sbodxuo4jm6ge5wduwowla.arweave.net/eAPZ9QtGQSupxLkJty77Sw6mckFw70dxLPGJ2w6WdZY"),
            tx.pure.address('0xe65f125538ff216c12106adfa9004813bba39b5fd58f45f453fb1a866e89c800'),
        ],
    });

    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx,
    });
    console.log({ result });
    const digest_ = result.digest;

    const txn = await client.getTransactionBlock({
        digest: String(digest_),
        // only fetch the effects and objects field
        options: {
            showEffects: true,
            showInput: false,
            showEvents: false,
            showObjectChanges: true,
            showBalanceChanges: false,
        },
    });
    let output: any;
    output = txn.objectChanges;
    let nft;

    for (let i = 0; i < output.length; i++) {
        const item = output[i];
        if (await item.type === 'created') {
            if (await item.objectType === `${packageId}::nft::NFT`) {
                nft = String(item.objectId);
            }
        }
    }
    console.log(`NFT : ${nft}`);
}


mintNft();
