obj buf[T]((T,T,T) data) {
  fn get(int i) -> T {
    if (i == 0) {
      ret data._0;
    } else {
      if (i == 1) {
        ret data._1;
      } else {
        ret data._2;
      }
    }
  }
}

fn main() {
  let buf[int] b = buf[int]((1,2,3));
  log b.get(0);
  log b.get(1);
  log b.get(2);
}
