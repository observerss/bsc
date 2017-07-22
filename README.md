# BSC: Python bingding for libbsc

## Install

```bash
pip install bsc
```

## Usage

API mimics `zlib`'s

```python
import bsc
assert b'1234' == bsc.decompress(bsc.compress(b'1234'))

# Incremental compressing
# Note that default block size is 25M, you'd better use it on
# very large streams
c = bsc.compressobj()
r = c.compress(b'1234')
r += c.compress(b'2345')
r += c.flush()
```

## Performance

See [Squash Benchmark](https://quixdb.github.io/squash-benchmark/)

## Link

[libbsc](http://libbsc.com)