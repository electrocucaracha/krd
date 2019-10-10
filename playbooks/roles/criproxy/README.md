# CRI Proxy

CRI Proxy makes it possible to run several CRI implementations on the
same node and run CRI implementations inside pods. CRI Proxy is
currently used by Virtlet project but it can be used by other CRI
implementations, too.

## How CRI Proxy works

Below is a diagram depicting the way CRI Proxy works. The basic idea
is forwarding the requests to different runtimes based on prefixes of
image name / pod id / container id prefixes.

![CRI Request Path](../../../docs/src/img/criproxy.png)
