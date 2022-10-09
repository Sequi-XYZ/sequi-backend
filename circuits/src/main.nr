use dep::std;

fn main(
  // all notes have the same denomination
  priv_key : Field, 
  // Merkle membership proof
  note_root : pub Field, 
  index : Field,
  note_hash_path : [Field; 32],
  // Random secret to keep note_commitment private
  secret: Field
) {
    // Compute public key from private key to show ownership
    let pubkey = std::scalar_mul::fixed_base(priv_key);
    let pubkey_x = pubkey[0];
    let pubkey_y = pubkey[1];
    
    // Compute input note commitment
    let note_commitment = std::hash::pedersen([pubkey_x, pubkey_y, secret]);
    
    // Check that the input note commitment is in the root
    let is_member = std::merkle::check_membership(note_root, note_commitment[0], index, note_hash_path);
    constrain is_member == 1;
}
