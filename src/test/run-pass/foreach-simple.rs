// -*- rust -*-

fn main() {
  for each (int i = first_ten()) {
    log "main";
    log i;
  }
}

iter first_ten() -> int {
  let int i = 97;
  while (i < 100) {
    log "first_ten";
    log i;
    put i;
    i = i + 1;
  }
}
