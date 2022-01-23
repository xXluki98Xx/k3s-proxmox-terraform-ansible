[master]
${k3s_master_ip}

[worker]
${k3s_worker_ip}

[storage]
${k3s_storage_ip}

[cache]
${k3s_cache_ip}

[k3s_cluster:children]
master
worker
storage