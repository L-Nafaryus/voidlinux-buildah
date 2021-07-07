Void Linux Images
=================
.. contents:: Table of contents

Buildah containers based on the `Void Linux <http://voidlinux.org>`_ operating system.
    
.. csv-table:: Current images
    :header: "Image", "Size"

    "voidlinux-musl", "~14 MB"
    "voidlinux-glibc", "~59 MB"
    "voidlinux-musl-minimal", "~77 MB"
    "voidlinux-glibc-minimal", "~121 MB"

Usage
-----
.. code-block:: bash

   ./voidlinux-buildah.sh [options ...]

Options:

``--musl|--glibc``
    Set a libc implementation (default: ``--musl``).

``--standart|--minimal``
    Set a type which determines additional packages (default: ``--standart``)

Building
--------
.. code-block:: bash

    buildah unshare ./voidlinux-buildah.sh --musl --build minimal

Running
-------
.. code-block:: bash

    ctr=$( podman run -dt voidlinux-musl-minimal )
    podman attach $ctr

License
-------
`CC0 <https://creativecommons.org/publicdomain/zero/1.0/>`_

For more informaion see ``LICENSE`` file in this repository.
