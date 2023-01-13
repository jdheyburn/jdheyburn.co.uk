---
title: Nix Cheat Sheet
description: One stop shop with some low-level snippets related to Nix.
type: posts
date: 2023-01-13
tags:
- code snippets
- nix
---

The world of Nix has a bit of a steep learning curve. As I write blog posts on the subject, I'll refer to some of the tips and tricks from the cheat sheet here.

## Resources

Here are a list of resources I use to search for Nix options, services, and any Nix built-in functions.

- [NixOS Search](https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance)
- [MyNixOS](https://mynixos.com/)
- [noogle](https://noogle.dev/)

## Functions (and Lambdas)

In some languages you typically have a formal declaration of a function (or lambda), such as for Python:

```python
def double_num(num_to_double)
  return num_to_double * 2
```

Nixlang is a functional language, and a typical behaviour of these is to define lambdas and assign them to variables.

```nix
double_num = num_to_double: num_to_double * 2
```

The lambda is defined when we create parameters for that lambda, which are defined by having a variable name prefixed by a colon. From the example above, the parameter for the `double_num` lambda is `num_to_double`.

Once all the parameters are defined we move onto the body, in which the final statement is returned, similarly to the [implicit return in Ruby](https://franzejr.github.io/best-ruby/idiomatic_ruby/implicit_return.html). Here we're just using the maths expression `num_to_double * 2` to have the intended outcome.

## Check if attribute is in attrset shorthand

You can use the built in function [hasAttr](https://nixos.org/manual/nix/stable/language/builtins.html#builtins-hasAttr) to determine if an attribute exists within an attrset.

```nix
$ attrSet = { key1 = "key1"; };

$ builtins.hasAttr "key1" attrSet
true

$ builtins.hasAttr "key2" attrSet
false
```

You can use the `?` operator as an alternate way of doing the same.

```nix
$ attrSet ? "key1"
true

$ attrSet ? "key2"
false
```

## Merge two attrsets shorthand

You can use the `//` operator to merge the contents of the attrset on the right into the attrset on the left.

```nix
$ newAttrset = { key1 = "key1"; } // { key2 = "key2"; }

$ newAttrset
{ key1 = "key1"; key2 = "key2"; }
```

If the attribute already exists in the left attrset, then it is overwritten.

```nix
$ attrSet = { key1 = "key1"; }

$ newAttrSet = attrSet // { key1 = "newKey1"; }

$ newAttrSet
{ key1 = "newKey1"; }
```

## Add an attribute to an attrset

Given an attrset with this structure:

```nix
$ items = {
  keyName = {
    value1 = "value";
    value2 = "value";
  }
}
```

We can use the `map` function to loop over each attrName (attribute name (aka key)) and its value in `items` to create a new attrset with its attrName added to it:

```nix
$ newItems = map
    (key: items."${key}" // { name = key; })
    (builtins.attrNames items);
```

The `map` function takes two parameters:

- a lambda that should be performed against each element
  - `(key: items."${key}" // { name = key; })`
    - This lambda takes a parameter `key`, and returns the attribute value at `items.key`, and merges it with the attrset `{ name = key; }` using the [[#Merge two attrsets shorthand]].
- a list of elements
  - `(builtins.attrNames items)`
  - `builtins.attrNames` is a function that takes a attrset and returns all the attribute names (keys) for it

So `newItems` will equal the below:

```nix
$ newItems
[
  {
    name = "keyName";
    value1 = "value";
    value2 = "value";
  }
];
```

The `map` function is also useful for converting an attrset to a list, since a list is what is returns by default.

```nix
$ items_list = map
    (key: items."${key}")
    (builtins.attrNames items);

$ items_list
[
  {
    value1 = "value";
    value2 = "value";
  }
]
```

## Converting a list to an attribute set

When we [[#Add an attribute to an attrset|add an attribute to an attset]], the `map` function returns a list, when we may want to have an attrset back instead.

We can use the `builtins.listToAttrs` function to convert it to one. It takes one argument, a list of attrsets that contain two attributes; `name` and `value` - the former becomes the attrName and the latter its value.

```nix
$ list = [
    {
        name = "keyName";
        value = {
            value1 = "value";
            value2 = "value";
        };
    }
    {
        name = "keyName2";
        value = {
            value3 = "value";
        };
    }
]

$ attrSet = builtins.listToAttrs list
```

`attrSet` will then equal the below:

```nix
attrSet = {
    keyName = {
        value1 = "value";
        value2 = "value";
    };
    keyName2 = {
        value3 = "value";
    };
}
```
