mod enums;

use enums::Intent;
fn main() {
    let a = Intent::NoIntent;
    let b = Intent::MaybeIntent;
    let c= Intent::Intent;

    for intent in &[a, b, c] {
        print!("intent: {:?}", intent);
    }

}
