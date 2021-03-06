---
date: 2020-07-20
title: "Assertions in gotests Test Generation"
description: Making more enhancements in gotests to produce test assertions
type: posts
tags:
  - golang
  - testing
---

I've been doing some programming in [Go](https://golang.org/) for a side project again, and I'm back using [gotests](https://github.com/cweill/gotests) to generate unit tests for functions. For this I've been referencing a post I've [previously written](/blog/extending-gotests-for-strict-error-tests/) in order to help me get them set up. If you'd like more context on the background I'd recommend reading there first.

Today I'll be talking about a small enhancement to how the tests are generated to make use of the [assert](https://godoc.org/github.com/stretchr/testify/assert) package within [testify](https://github.com/stretchr/testify). Go already comes with enough for you to write tests, but `assert` provides me with more options for comparison in a natural language form. I'll also be adding support for when a test case returns an unexpected error.

Don't care about the waffle? Jump straight to [it here](#customising-gotests-generated-test-v2).

## Recap

From the last time we visited this, our test code took the format below.

```go
func Test_validateDogName(t *testing.T) {
    type args struct {
        name string
    }
    tests := []struct {
        name    string
        args    args
        want    bool
        wantErr error
    }{
        name: "Test error was thrown for dog name with symbols",
        args: args{
            name: "GoodestBoy#1",
        },
        want: false,
        wantErr: errors.New("dog cannot have symbols in their name"),
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := validateDogName(tt.args.name)
            if tt.wantErr != nil && !reflect.DeepEqual(err, tt.wantErr) {
                t.Errorf("validateDogName() error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if got != tt.want {
                t.Errorf("validateDogName() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

Although this works nicely, there is one issue - we're not capturing unexpected errors. Or rather, if an error is returned to `err`, and `tt.wantErr` is set to `nil`, then the test will not fail.

Okay, so we still have the `if got != tt.want` condition to fail the test if needed. Although we still could have this condition pass, we want to make sure we capture the error. The test suite is doing currently is _assuming_ we don't care about the outcome of `err`, just because we didn't want one as described by `tt.wantErr`.

I seem to remember assumptions being the ~~brother~~ mother of something...

{{< youtube G-2NimrRPAQ >}}

## Enhancing for Unexpected Errors

In order to enhance what we have already from the original modified [function.tmpl](https://gist.github.com/jdheyburn/978e7b84dc9c197bcdd41afece2edab5), we could have it output something like this to capture unexpected errors.

```go {hl_lines=["5-8"]}
// ... removed for brevity
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        got, err := validateDogName(tt.args.name)
        if err != nil && tt.wantErr == nil {
            t.Errorf("validateDogName() unexpected error = %v", err)
            return
        }
        if tt.wantErr != nil && !reflect.DeepEqual(err, tt.wantErr) {
            t.Errorf("validateDogName() error = %v, wantErr %v", err, tt.wantErr)
            return
        }
        if got != tt.want {
            t.Errorf("validateDogName() = %v, want %v", got, tt.want)
        }
    })
}
```

The highlighted lines show the new addition. This is something we could implement fairly easily. On the other hand, the `assert` library gives us a lot more to play with. It essentially is doing the same as the above under the hood, albeit in a cleaner fashion... and I'm all for better code readability!

### Rewriting for Assert

```go {hl_lines=["21-32"]}
func Test_validateDogName(t *testing.T) {
    type args struct {
        name string
    }
    tests := []struct {
        name    string
        args    args
        want    bool
        wantErr error
    }{
        name: "Test error was thrown for dog name with symbols",
        args: args{
            name: "GoodestBoy#1",
        },
        want: false,
        wantErr: errors.New("dog cannot have symbols in their name"),
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := validateDogName(tt.args.name)
            if err != nil && tt.wantErr == nil {
                assert.Fail(t, fmt.Sprintf(
                    "Error not expected but got one:\n"+
                        "error: %q", err),
                )
                return
            }
            if tt.wantErr != nil {
                assert.EqualError(t, err, tt.wantErr.Error())
                return
            }
            assert.Equal(t, tt.want, got)
        })
    }
}
```

The above code block is what we get when we take the test code above that is using the `t.Errorf` function call to record a test failure, and rewrite it to use `assert`.

What we now need to do is have `gotests` generate it for us.

## Customising Gotests Generated Test v2

We'll be following a process similar to when I [last did this](/blog/extending-gotests-for-strict-error-tests/#customising-gotests-generated-test). I'm still using VSCode, so you'll need to find the [correct plugin](https://github.com/cweill/gotests/#demo) for your editor.

1. Check out gotests and copy the templates directory to a place of your choosing
   - `git clone https://github.com/cweill/gotests.git`
   - `cp -R gotests/internal/render/templates ~/.vscode/gotests/templates`
2. In order for us to achieve the generated test using `assert`, this time we're going to need to edit two files; `function.tmpl` and `results.tmpl`
   - Overwrite the contents of `function.tmpl` with the [contents of this Gist](https://gist.github.com/jdheyburn/94eb1513395ae46eac6aa9721d089d3c#file-function-tmpl)
   - Overwrite the contents of `results.tmpl` with the [contents of this Gist](https://gist.github.com/jdheyburn/94eb1513395ae46eac6aa9721d089d3c#file-results-tmpl)
3. Add the following setting to VSCode’s settings.json
   - `"go.generateTestsFlags": ["--template_dir=~/.vscode/gotests/templates"]`

Now we can generate tests of functions that return the following:

1. only returns an error
1. a value, and an error
1. multiple values, and an error

I have the [Go plugin](https://marketplace.visualstudio.com/items?itemName=golang.go) for VSCode, so I just need to right click over a function to have the dropdown menu appear with an option to generate tests.

{{< figure src="generate-unit-tests.png" link="generate-unit-tests.png" caption="" alt="VSCode dropdown with Go plugin" >}}

### Only returns an error

```go
func Test_validateDogName(t *testing.T) {
    type args struct {
        name string
    }
    tests := []struct {
        name    string
        args    args
        wantErr error
    }{
        // TODO: Add test cases.
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := validateDogName(tt.args.name)
            if err != nil && tt.wantErr == nil {
                assert.Fail(t, fmt.Sprintf(
                    "Error not expected but got one:\n"+
                        "error: %q", err),
                )
            }
            if tt.wantErr != nil {
                assert.EqualError(t, err, tt.wantErr.Error())
            }
        })
    }
}
```

### Returns a value, and an error

```go
func Test_validateDogName(t *testing.T) {
    type args struct {
        name string
    }
    tests := []struct {
        name    string
        args    args
        want    bool
        wantErr error
    }{
        // TODO: Add test cases.
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := validateDogName(tt.args.name)
            if err != nil && tt.wantErr == nil {
                assert.Fail(t, fmt.Sprintf(
                    "Error not expected but got one:\n"+
                        "error: %q", err),
                )
                return
            }
            if tt.wantErr != nil {
                assert.EqualError(t, err, tt.wantErr.Error())
                return
            }
            assert.Equal(t, tt.want, got)
        })
    }
}
```

### Returns multiple values, and an error

```go
func Test_validateDogName(t *testing.T) {
    type args struct {
        name string
    }
    tests := []struct {
        name    string
        args    args
        want    bool
        want1   bool
        wantErr error
    }{
        // TODO: Add test cases.
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, got1, err := validateDogName(tt.args.name)
            if err != nil && tt.wantErr == nil {
                assert.Fail(t, fmt.Sprintf(
                    "Error not expected but got one:\n"+
                        "error: %q", err),
                )
                return
            }
            if tt.wantErr != nil {
                assert.EqualError(t, err, tt.wantErr.Error())
                return
            }
            assert.Equal(t, tt.want, got)
            assert.Equal(t, tt.want1, got1)
        })
    }
}
```

### Bonus: Only returns values

The below example is for a function that doesn't produce any errors, but I'm including it for the sake of completeness.

```go
func Test_validateDogName(t *testing.T) {
    type args struct {
        name string
    }
    tests := []struct {
        name string
        args args
        want bool
    }{
        // TODO: Add test cases.
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := validateDogName(tt.args.name)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

## That's It!

This is just a short update to an enhancement I [previously made](/blog/extending-gotests-for-strict-error-tests/) to gotests. The `assert` library is awesome for test cases and it's great to have it autogenerated in my tests too.
