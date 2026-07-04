# Piraeus Controlled RWX Cleanup Health

## Benchmark namespace after app removal
No resources found

## LinstorCluster after benchmark app removal
apiVersion: v1
items: []
kind: List
metadata:
  resourceVersion: ""

## LINSTOR resources after benchmark app removal
Error from server (NotFound): deployments.apps "linstor-controller" not found

## Node taints after Piraeus benchmark removal
["dauwalter",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-04T12:51:20Z"}]]
["fordyce",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-04T12:51:20Z"}]]
["kipsang",[]]
["selassie",[{"effect":"NoSchedule","key":"drbd.linbit.com/lost-quorum","timeAdded":"2026-07-04T12:51:20Z"}]]
["walmsley",[]]
