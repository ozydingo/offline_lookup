##Offline Lookup

Alhpa (0.0.3). Use at your own risk.

IMPORTANT: don't use this for models that have a lot of data!!
This is basically a in-memory pseudo-index intended to speed up quick, repeated
finds of index table values without trips to an external db machine.
It's also nicer syntax, e.g:

```
TurnaroundLevel.two_hour_id
TurnaroundLevel.quick_lookup("Two Hour")
Service.last.turnaround_level.two_hour?
```

In any ActiveRecord::Base subclass, use:

`use_offline_id_lookup column_name`

to define class methods that can convert between id and the corresponding
value in `column_name` for the class, without going to the database

`column_name` defaults to `:name`, but can be any column of the table
use the `:key` keyword arg if you're interested in a key colun other than `:id`
Usage example:

```
class TurnaroundLevel < ActiveRecord::Base
  use_offline_lookup :level
  ...
end
```

If, for example, the first row of the turnaround_levels table has a `:level` of `"Same Day"`, this gives you

```
TurnaroundLevel.same_day_id
#=> 1
TurnaroundLevel.name_for_id(1)
#=> 'Same Day'
TurnaroundLevel.id_for_name('Same Day')
#=> 1
TurnaroundLevel.first.same_day?
#=> true
TurnaroundLevel.same_day
#=> <#TurnaroundLevel id: 1, level: "Same Day", ...>
```

The last of these methods is the "lookup" method, and is not quite offline. This is because we only store the key - name mappings, not the entire objects, in memory when we declare a new offline_lookup model. However it is included by default for convenient syntax (and it uses a lookup on what is usually the primary key of the table, in case the extra few ms matter to you). You can disable it by using

`use_offline_lookup :level, lookup_methods: false`

You can also disable the identity methods (e.g. `TurnaroundLevel.first.same_day?`) by using

`use_offline_lookup :level, identity_methods: false`

(And yes, the keywords can be combined, they're all optional keyword args)

## Known Issues

If two entries in the table have the same value in the specified field, all but one will get overwritten. In a future version, I plan to allow multiple-column specificaion, e.g. `use_offline_lookup [:firstname, :lastname]`
