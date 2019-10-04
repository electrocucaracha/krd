# Persistent Memory

The term persistent memory is used to describe technologies which
allow programs to access data as memory, directly byte-addressable,
while the contents are non-volatile, preserved across power cycles. It
has aspects that are like memory, and aspects that are like storage,
but it doesn’t typically replace either memory or storage. Instead,
persistent memory is a third tier, used in conjunction with memory and
storage.

With this new ingredient, systems containing persistent memory can
outperform legacy configurations, providing faster start-up times,
faster access to large in-memory datasets, and often improved total
cost of ownership.

Intel PMEM-CSI is a storage driver for like Kubernetes which makes
local persistent memory (PMEM) available as a filesystem volume to
container applications. Currently utilize non-volatile memory devices
that can be controlled via the libndctl utility library.
