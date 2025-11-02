#[derive(Debug)]
pub enum Intent {
    NoIntent,
    Intent,
    MaybeIntent
}


#[derive(Debug)]
pub enum UserStatus {
  Active,
  Inactive,
  Blocked
}
