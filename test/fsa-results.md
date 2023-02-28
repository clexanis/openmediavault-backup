# FSArchiver Result

Here are the results of the tests I've made with different parameters for the compressor and on different configurations.

The platforms are a Raspberry Pi 1, a type 1 VM using 4 core of a Neoverse-N1 with 24 GB RAM, and a type 2 VM using 4 core of a Intel Core i5-4570 with 8 GB RAM.

The RPI 1 and the ARM64 VM aren't using OMV, but are all based on Debian system.

## Time

| zstd level     | 1        | 2        | 3        | 4        | 5        | 8 (default) | 11       | 15       | 17       | 20       | 22       |
|----------------|----------|----------|----------|----------|----------|-------------|----------|----------|----------|----------|----------|
|                | Time (s) | Time (s) | Time (s) | Time (s) | Time (s) | Time (s)    | Time (s) | Time (s) | Time (s) | Time (s) | Time (s) |
| Raspberry Pi 1 |      530 |      587 |          |          |          |        1312 |          |          |          |          |          |
| Neoverse-N1    |       47 |       43 |       44 |       47 |       52 |          61 |       73 |      146 |      306 |      598 |      744 |
| Intel i5-4570  |       58 |       14 |       13 |       16 |       20 |          29 |       33 |       73 |      114 |      210 |      253 |

## Size

| zstd level    | 1         | 2         | 3         | 4         | 5         | 8 (default) | 11        | 15        | 17        | 20        | 22        |
|---------------|-----------|-----------|-----------|-----------|-----------|-------------|-----------|-----------|-----------|-----------|-----------|
|               | Size (MB) | Size (MB) | Size (MB) | Size (MB) | Size (MB) | Size (MB)   | Size (MB) | Size (MB) | Size (MB) | Size (MB) | Size (MB) |
| Neoverse-N1   |   8275.93 |   8214.43 |   8169.17 |   8164.06 |   8129.29 |     8079.95 |   8074.38 |   8061.15 |   8003.14 |   7886.20 |   7884.94 |
| Intel i5-4570 |   1126.44 |   1093.30 |   1071.81 |   1068.44 |   1051.23 |     1021.86 |   1018.89 |   1011.41 |    981.53 |    935.85 |    935.70 |
