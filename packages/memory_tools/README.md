


This code cannot be part of `devtools_shared`, because
the version resolution fails for flutter:

```
Because every version of flutter from sdk depends on devtools_shared from path which depends on 
vm_service ^9.0.0, every version of flutter from sdk requires vm_service ^9.0.0.
So, because flutter_automated_tests depends on both flutter from sdk and vm_service 8.2.2, 
version solving failed.
pub get failed (1; So, because flutter_automated_tests depends on both flutter from sdk 
and vm_service 8.2.2, version solving failed.)
exit code 1
```
