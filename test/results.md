# Result

Here are the results of the tests I've made with different parameters for the compressor and on different configurations.

The platfoms are a Raspberry Pi 1, a type 1 VM using 4 core of a Neoverse-N1 with 24 GB RAM, and a type 2 VM using 4 core of a Intel Core i5-4570 with 8 GB RAM.

The RPI 1 and the ARM64 VM aren't using OMV, but are all based on Debian system.

## Speed

|                |   dd    | default | Gzip (optimized) | Pigz | Zstd | Zstd 1.5.4 |
|----------------|:-------:|:-------:|:----------------:|:----:|:----:|:----------:|
|                |    MB/s |    MB/s |             MB/s | MB/s | MB/s |       MB/s |
| Raspberry Pi 1 |    11.6 |     1.1 |              2.2 |  2.7 |  5.5 |        6.2 |
| Neoverse-N1    |    86.7 |    39.6 |             50.2 | 50.5 | 86.9 |            |
| Intel i5-4570  | [^1]482 |      63 |              103 |  221 |  298 |        294 |

>[^1]The dd reference serve to estimate the maximum read speed of the device, but isn't reliable for the i5-4570.

We could see that changing the profile for gzip give a large speedup on all platform (+100% on the Raspberry Pi 1 !).

As for pigz, which is compatible with the current file format used, we could observe a weird result. Another large speedup on the AMD64 platfom, even a little speedup on the RPI1, but almost none on the ARM64 who have 4 cores. After some search, turn out that the culprit is an old library used on Debian Bookworm [see here](#pigz-issue-on-arm64).

Zstd give an impressing gain, hitting the ceiling wall imposed by the backing device on higher end target, and the latest version (manually compiled) is even better. Shame it would break the compatibility on the current file format.

## Time

|                |    dd    |  default | Gzip (optimized) |   Pigz   |   Zstd   | Zstd 1.5.4 |
|----------------|:--------:|:--------:|:----------------:|:--------:|:--------:|:----------:|
|                | Time (s) | Time (s) |     Time (s)     | Time (s) | Time (s) |  Time (s)  |
| Raspberry Pi 1 |      174 |     1881 |              906 |      763 |      373 |        332 |
| Neoverse-N1    |      582 |     1279 |              810 |  [^2]584 |      583 |        583 |
| Intel i5-4570  |       44 |      345 |              215 |      101 |       76 |         77 |

>[^2]: Same as with the last test, [see here](#pigz-issue-on-arm64).

Since the different systems aren't using consistent bases, we can't directly compare the results.

We could still see the same kind of gain as we observed before.


## Size

|           | default | Gzip (optimized) |   Pigz  |   Zstd  | Zstd 1.5.4 |
|-----------|:-------:|:----------------:|:-------:|:-------:|:----------:|
| Size (GB) | 2.04e+3 |          2.23e+3 | 2.22e+3 | 2.24e+3 |    2.27e+3 |

We lose on final sizes, but with zstd on higher end platform, we could regain some by using higher compression level without loosing speed, since we achieve the maximum read speed of the backing device.

### Pigz issue on arm64

After some research, I found people speaking about improvement of zlib and pigz on the same kind of platform I found the weird result [here](https://github.com/WorksOnArm/equinix-metal-arm64-cluster/issues/195), and about the lack of accelerated CRC usage on some ARM platform.

I then checked the changelogs of the latest version of pigz and zlib, and found that a more recent version of zlib, who isn't available on the Debian repository, have now this functionality.

| Pigz         |          |Pigz (local build)|          |
|:------------:|:--------:|:----------------:|:--------:|
| Speed (MB/s) | Time (s) |   Speed (MB/s)   | Time (s) |
|         50.5 |     1004 |             86.8 |      584 |

With the latest build of zlib library and pigz, the result of the ARM64 platform is now on par with the others platforms.
