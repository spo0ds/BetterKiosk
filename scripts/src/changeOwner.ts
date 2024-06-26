import { TransactionBlock } from '@mysten/sui.js/transactions';
import * as dotenv from 'dotenv';
import getExecStuff from '../utils/execStuff';
import { packageId, Kiosk, KioskOwnerCap } from '../utils/packageInfo';
dotenv.config();


async function changeOwner() {
    const { keypair, client } = getExecStuff();
    const tx = new TransactionBlock();
    const pt = tx.moveCall({
        target: `${packageId}::kiosk::set_owner_custom`,
        arguments: [
            tx.object(Kiosk),
            tx.object(KioskOwnerCap),
            tx.pure.address("0xe65f125538ff216c12106adfa9004813bba39b5fd58f45f453fb1a866e89c800"),
        ],
    });

    const result = await client.signAndExecuteTransactionBlock({
        signer: keypair,
        transactionBlock: tx,
    });
    console.log({ result });
    console.log(pt);
}


changeOwner();
