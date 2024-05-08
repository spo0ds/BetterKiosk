import { TransactionBlock } from '@mysten/sui.js/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { packageId } from '../utils/packageInfo';
dotenv.config();

const kioskId = async () => {
    try {
        const { keypair, client } = getExecStuff();
        const tx = new TransactionBlock();

        tx.moveCall({
            target: `${packageId}::kiosk::default`,
            arguments: [],
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
        let Kiosk: any;
        let KioskOwnerCap: any;

        for (let i = 0; i < output.length; i++) {
            const item = output[i];
            if (item.type === 'created') {
                if (item.objectType === `${packageId}::kiosk::KioskOwnerCap`) {
                    KioskOwnerCap = String(item.objectId);
                }
                if (item.objectType === `${packageId}::kiosk::Kiosk`) {
                    Kiosk = String(item.objectId);
                }
            }
        }

        return {
            Kiosk, KioskOwnerCap
        };
    } catch (error) {
        // Handle potential errors if the promise rejects
        console.error(error);
        return { Kiosk: '', KioskOwnerCap: '' };
    }
}

kioskId()
    .then((result) => {
        console.log(result);
    })
    .catch((error) => {
        console.error(error);
    });

export default kioskId;