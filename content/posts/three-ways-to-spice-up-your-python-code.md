---
draft: true
date: 2019-07-04
title: Three Ways To Spice Up Your Python Code
description: I describe some simple methods to make your Python code much more durable and integral...?
tags:
- python
- testing
- typing
---

# Spice Up Your ~~Life~~ Python

I'm currently working on a side project that I've written in Python. Now I've have a lot of experience with Python before, I used it primarily to write a load of scripts for automating processes for when Bash didn't quite cut it. Don't get me wrong Bash is great, but like for every other language out there, each has its purpose. My experience with Python didn't go beyond setting some variables, hitting endpoints, executing some Bash commands to install some vendor components - however during my experience I came across some poorly written scripts that I caused some pet peeves:  what object a function is expecting, or what it returns? Did I break some downstream function? This made it terribly difficult to add a new feature to a script. 

(talk about how Python is good for throwing together something quick, because it implies on types)

With this side project I wanted to make it right from the start. So I said to myself these are the key areas I want to target:

1. The application must be extensively tested (did I mention I [love tests?](/posts/extending-gotests-for-strict-error-tests/))
1. Functions must clearly define what the type of the objects the parameters are, and what the types of the objects they return are.
1. ??

From this list, we can include the following to solve the above:

1. [Static type checking](#static-type-checking)
1. Classes (- is this not above?)
1. ...and tests! (well duh!)

# Static Type Checking

As I mentioned before, Python is great for throwing together a script to automate some task. It's quick and easy to do mainly because the type of a variable is implied from whatever you set to it.

```python
>>> my_int_var = 1
>>> type(my_int_var)
<class 'int'>
```

This also applies to functions that take in a parameter, the type for it is implied from what it receives! Let's say we have a function that takes in a parameter (expected to be an `int`), increments it by 1, and prints out the result:

```python
def increment_int_by_one(int_to_increment):
    incremented_int = int_to_increment + 1
    print(incremented_int)

>>> increment_int_by_one(1)  
2                            
>>> increment_int_by_one(100)
101                          
```

All good so far. But what happens when we pass in something that is not an int, such as a string?
```python
>>> increment_int_by_one("1")
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
  File "<stdin>", line 2, in increment_int_by_one
TypeError: must be str, not int
```

Yikes, that's a misleading error! We're receving a `TypeError` on the `int` value we are incrementing to the parameter, which in this case is simply `1`. If you had inherited a library and you saw this error, you'd be none the wiser on what the true type the function expects!

> Under the hood, Python believe you are trying to do a __string concatenation__ because the parameter is of type string, and is on the left-hand side of the + operator. The below shows a valid way to perform a string concatenation:

> `"1" + "1" # -> "11"`

>
> If the int value was on the left-hand side of the operator and you passed a string, you'd get something like this:
> ```
>>> 1 + "1"
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: unsupported operand type(s) for +: 'int' and 'str'
```

Luckily there is a better way...

## Implementation

Python 3.6 onwards introduced static type checking, so make sure you upgrade to it if you haven't already - which you might want to do very soon as Python 2 is [EOL in 2020](https://pythonclock.org/)! 







