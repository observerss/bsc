from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from libc.string cimport memcpy


cdef extern from "libbsc/libbsc.h":
    cdef int LIBBSC_NO_ERROR                
    cdef int LIBBSC_BAD_PARAMETER 
    cdef int LIBBSC_NOT_ENOUGH_MEMORY
    cdef int LIBBSC_NOT_COMPRESSIBLE
    cdef int LIBBSC_NOT_SUPPORTED
    cdef int LIBBSC_UNEXPECTED_EOB
    cdef int LIBBSC_DATA_CORRUPT
    cdef int LIBBSC_CODER_NONE
    cdef int LIBBSC_CODER_QLFC_STATIC
    cdef int LIBBSC_CODER_QLFC_ADAPTIVE
    cdef int LIBBSC_FEATURE_NON
    cdef int LIBBSC_FEATURE_FASTMODE
    cdef int LIBBSC_FEATURE_MULTITHREADING
    cdef int LIBBSC_FEATURE_LARGEPAGES
    cdef int LIBBSC_FEATURE_CUDA
    cdef int LIBBSC_DEFAULT_LZPHASHSIZE
    cdef int LIBBSC_DEFAULT_LZPMINLEN
    cdef int LIBBSC_DEFAULT_BLOCKSORTER
    cdef int LIBBSC_DEFAULT_CODER
    cdef int LIBBSC_DEFAULT_FEATURES
    cdef int LIBBSC_HEADER_SIZE

    cdef int bsc_init(int features)
    cdef int bsc_compress(const unsigned char * input, unsigned char * output, int n, int lzpHashSize, int lzpMinLen, int blockSorter, int coder, int features)
    cdef int bsc_store(const unsigned char * input, unsigned char * output, int n, int features)
    int bsc_block_info(const unsigned char * blockHeader, int headerSize, int * pBlockSize, int * pDataSize, int features)
    cdef int bsc_decompress(const unsigned char * input, int inputSize, unsigned char * output, int outputSize, int features)


BSC_RUNTIME_VERSION = '3.1.0'

ERROR_MSGS = {
    LIBBSC_BAD_PARAMETER: 'bad parameter',
    LIBBSC_NOT_ENOUGH_MEMORY: 'not enough memory',
    LIBBSC_NOT_COMPRESSIBLE: 'not compressible',
    LIBBSC_NOT_SUPPORTED: 'not supported',
    LIBBSC_UNEXPECTED_EOB: 'unexcepted eob',
    LIBBSC_DATA_CORRUPT: 'data corrupt',
}


ctypedef unsigned char BYTE
ctypedef long long INT64


cdef BYTE[4] BSC_FILE_SIGN = b'bsc1'
cdef struct BlockPrefix:
    INT64 offset
    BYTE size
    BYTE sorter


def compressobj(
        block_size=25 * 1024 * 1024,
        hash_size=16,
        min_length=128,
        sorter=5,
        coder=2):
    return Compress(block_size, hash_size, min_length, sorter, coder)


def decompressobj():
    return Decompress()


cdef class Compress:
    cdef:
        bytes _data
        int _block_size, _hash_size, _min_length, _sorter, _coder

    def __init__(self, 
                 int block_size=25 * 1024 * 1024,
                 int hash_size=16, 
                 int min_length=128,
                 int sorter=5,
                 int coder=2):
        self._block_size = block_size
        self._hash_size = hash_size
        self._min_length = min_length
        self._sorter = sorter
        self._coder = coder
        bsc_init(LIBBSC_DEFAULT_FEATURES)
        self._data = b''

    def compress(self, bytes data):
        cdef bytes result = b''
        self._data += data
        while len(self._data) >= self._block_size:
            result += self._compress(self._data[:self._block_size])
            self._data = self._data[self._block_size:]
        return result

    cdef bytes _compress(self, bytes data):
        cdef bytes result
        cdef int bsize
        cdef BYTE* buff = <BYTE*>PyMem_Malloc(
            (len(data) + LIBBSC_HEADER_SIZE) * sizeof(BYTE))
        memcpy(buff, <BYTE*>data, len(data))
        bsize = bsc_compress(buff, buff, len(data),
            self._hash_size,
            self._min_length,
            self._sorter,
            self._coder,
            LIBBSC_DEFAULT_FEATURES)
        if bsize == LIBBSC_NOT_COMPRESSIBLE:
            memcpy(buff, <BYTE*>data, len(data))
            bsize = bsc_store(buff, buff, len(data), LIBBSC_DEFAULT_FEATURES)
        if bsize < LIBBSC_NO_ERROR:
            PyMem_Free(buff)
            raise RuntimeError(ERROR_MSGS[bsize])
        result = buff[:bsize]
        PyMem_Free(buff)
        return result

    def flush(self):
        cdef bytes result = self._compress(self._data)
        self._data = b''
        return result


cdef class Decompress:
    cdef bytes _data
    cdef int _bsize, _dsize
        
    def __init__(self):
        self._data = b''
        self._bsize = self._dsize = 0
        bsc_init(LIBBSC_DEFAULT_FEATURES)

    cdef _parse_header(self):
        cdef BYTE* hbuf = <BYTE*>PyMem_Malloc(LIBBSC_HEADER_SIZE * sizeof(BYTE))
        cdef int code
        memcpy(hbuf, <BYTE*>self._data, LIBBSC_HEADER_SIZE)
        code = bsc_block_info(hbuf, LIBBSC_HEADER_SIZE, &self._bsize, &self._dsize,
             LIBBSC_DEFAULT_FEATURES)
        if code < LIBBSC_NO_ERROR:
            PyMem_Free(hbuf)
            raise RuntimeError(ERROR_MSGS[code])
        PyMem_Free(hbuf)

    @property
    def unconsumed_tail(self):
        return self._data
        
    def decompress(self, bytes data):
        cdef bytes result = b''
        self._data += data
        if not self._bsize:
            self._parse_header()
        while self._data and self._bsize <= len(self._data):
            result += self._decompress(
                self._data[:self._bsize])
            self._data = self._data[self._bsize:]
            self._bsize = self._dsize = 0
            if len(self._data) >= LIBBSC_HEADER_SIZE:
                self._parse_header()
        return result

    cdef bytes _decompress(self, bytes data):
        cdef bytes result
        cdef int code, buffsize
        cdef BYTE* buff
        
        buffsize = max(len(data), self._dsize)
        buff = <BYTE*>PyMem_Malloc(buffsize * sizeof(BYTE))
        memcpy(buff, <BYTE*>data, len(data))
        code = bsc_decompress(
            buff, self._bsize, buff, self._dsize, LIBBSC_DEFAULT_FEATURES)
        if code < LIBBSC_NO_ERROR:
            PyMem_Free(buff)
            raise RuntimeError(ERROR_MSGS[code])
        result = buff[:self._dsize]
        PyMem_Free(buff)
        return result

    def flush(self):
        return b''


def compress(data,
             block_size=25 * 1024 * 1024,
             hash_size=16,
             min_length=128,
             sorter=5,
             coder=2):
    c = Compress(block_size, hash_size, min_length, sorter, coder)
    out = c.compress(data)
    out += c.flush()
    return out


def decompress(data):
    d = Decompress()
    out = d.decompress(data)
    if d.unconsumed_tail:
        raise RuntimeError('data incomplete')
    return out
