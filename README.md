#Offline Lookup

Store lookup values for small tables for fewer db queries and syntactic sugar.

## The quickest examples:
Lets say you have a model `PostType` with a few rows that define various types of Posts.

`PostType.find_by(name: "reply").id`
becomes simply
`Post.reply_id`

Where the latter form does not execute a database query. Instead, a mapping of id to name is kept in the class instance. Thus, this is good only for small lookup-type tables, not for full tables of data.

A couple more:
`PostType.find_by(name: name)` becomes `PostType.lookup(name)`
`post_type.name == "reply"` becomes `post_type.reply?` (disabled by default, use `identity_methods: true`)
`Post.find_by(name: "reply") becomes `PostType.reply` (disabled by default, use `lookup_methods: true`)

More flexible, still no db queries:
`PostType.find_by(name: name).id` becomes `PostType.id_for_name(name)`
`PostType.find(1).name` becomes `PostType.name_for_id(1)`

IMPORTANT: don't use this for models that have a lot of data!! While OfflineLookup only stores primary key and lookup column values, you don't usually want this loading thousands or millions of such values into memory. Rule of thumb, keep it in the tens or below.

### What's New

v1.0.0
`lookup_methods` and `identity_methods` now default to false. If you use the `TurnaroundLevel.two_hour` or `TurnaroundLevel.first.two_hour?` methods, pass either `lookup_methods: true` or `identity_methods: true` into `use_offline_lookup`.

Add `lookup` method to allow lookup by key'd name without risking bad / reserved-keyword method names (e.g. "parent")

You can now specify multiple columns for lookup! The values are by default joined with a " " (note this translates to "_" for method names). You can configure this delimiter and what to do with `nil` values.

v1.1.0
I forget. Probably a big bugfix.

v1.2.0
Definitely a big bugfix. The core OfflineLookup module was getting included in all of ActiveRecord, which mistakenly included callback methods that depended on the existence of `self.offline_lookup_options`. This has been fixed and this behavior is now only exhibited on models that explicitly call `use_offline_lookup`


## How To Use It

### By Example

```
class TurnaroundLevel
  use_offline_lookup :name
end

# Return the id of the TurnaroundLevel named "Two Hour"
TurnaroundLevel.two_hour_id
TurnaroundLevel.id_for_name("Two Hour")
# Return the instance of TurnaroundLevel with the name "Two Hour"
TurnaroundLevel.lookup("Two Hour")
#Return the name of the TurnaroundLevel with id 7
TurnaroundLevel.name_for_id(7)
```

A few extra options:
```
class TurnaroundLevel
  use_offline_lookup :name, lookup_method: true, identity_method: true
end

# Return true if the last TurnaroundLevel is the "Two Hour" level. Uses the `:identify_methods` options.
TurnaroundLevel.last.two_hour?
# Return the "Two Hour" TurnaroundLevel instance. Uses the `:lookup_methods` option
TurnaroundLevel.two_hour

```

### By Spec

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
TurnaroundLevel.lookup(`Same Day`)
#=> <#TurnaroundLevel id: 1, level: "Same Day", ...>
```

If you use the option `identity_methods: true`, you get

```
TurnaroundLevel.first.same_day?
#=> true
```

Using `lookup_methods: true`:

```
TurnaroundLevel.same_day
#=> <#TurnaroundLevel id: 1, level: "Same Day", ...>
```

This is not quite offline. This is because we only store the key - name mappings, not the entire objects, in memory when we declare a new offline_lookup model. However it is included by default for convenient syntax (and it uses a lookup on what is usually the primary key of the table, in case the extra few ms matter to you).


You can use combinations of columns to define the lookup values

```
class Admin < ActiveRecord::Base  # firstname, lastname
  use_offline_lookup :firstname, :lastname
end

Admin.john_doe_id
Admin.lookup("John Doe")
```

Option include
`delimiter` (default: `'_'`): character or string to join values between columns
`compact` (default: `false`): exclude nil columns from joining with delimiter
`name` (default: fields.join(delimiter)): name for this lookup

E.g. on `name`:
```
class Admin < ActiveRecord::Base  # firstname, lastname
  use_offline_lookup :firstname, :lastname, name: "name"
end
Admin.id_for_name("John Doe")
```

You can also define your own method of generaing the lookup name using the `:transform` options. The default is to ust the field, or delimiter-concatentaed fields. To specify a transofmation, provide a lambda whose arguments are the fields being used by OfflineLookup

```
class Admin < ActiveRecord::Base
  use_offline_lookup :lastname, transform: ->(lastname){"lookup_#{lastname}"}
end
```

Or for multiple fields
```
class Admin < ActiveRecord::Base
  use_offline_lookup :firstname, :lastname, transform: ->(first, last){"#{first.first}_#{last}"}
end
```

## Known Issues

If two entries in the table have the same value in the specified field, all but one will get overwritten.

Be aware that if the lookup name is a keyword or existing method, this can cause issues! For example, I encountered a use of offline lookup where the lookup column was `lastname` of a small `Admin` table. One of the last names was "parent". With `identity_methods: true`, this defined the `Admin.parent` method, which of course caused issues since `parent` on a class is supposed to mean something else! If you have potentially dangerous values, leave lookup_methods disabled and just use `Admin.lookup("Parent")` instead.
