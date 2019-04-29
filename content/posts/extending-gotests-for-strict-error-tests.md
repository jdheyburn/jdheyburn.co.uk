---
date: 2019-04-29
title: Extending Gotests for Strict Error Tests
description: Here I document about a custom template used for enhancing how errors are tested in the gotests library.
tags:
- golang
- java
- testing
---

# Strict Error Tests in Java
I love confirming the stability of my code through writing tests and practicing Test-driven development (TDD).  For Java, JUnit was my preferred testing framework of choice. When writing tests to confirm an exception had been thrown, I used the optional parameter `expected` for the annotation `@Test`, however I quickly found that this solution would not work for methods where I raised the same exception class multiple times for different error messages, and testing on those messages. 

This is commonly found in writing a validation method such as the one below, which will take in a name of a dog and return a boolean if it is valid. 

```java
public static boolean validateDogName(String dogName) throws DogValidationException {

    if (containsSymbols(dogName)) {
        throw new DogValidationException("Dogs cannot have symbols in their name!");
    }
    
    if (dogName.length > 100) {
        throw new DogValidationException("Who has a name for a dog that long?!");
    }

    return true;
}
```

For this method, just using `@Test(expected = DogValidationException.class)` on our test method is not sufficient; how can we determine that the exception was raised for a dogName.length breach and not for containing symbols?

In order for me to resolve this, I came across the `ExpectedException` class for JUnit on [Baeldung](https://www.baeldung.com/junit-assert-exception) which enables us to specify the error message expected. Here it is applied to the test case for this method:
```java
@Rule
public ExpectedException exceptionRule = ExpectedException.none();

@Test
public void shouldHandleDogNameWithSymbols() {
    exceptionRule.expect(DogValidationException.class);
    exceptionRule.expectMessage("Dogs cannot have symbols in their name!");
    validateDogName("GoodestBoy#1");
}
```

# Applying to Golang

Back to Golang, there is a built-in library aptly named `testing` which enables us to assert on test conditions. When combined with [Gotests](https://github.com/cweill/gotests) - a tool for generating Go tests from your code - writing tests could not be easier! I love how this is bundled in with the Go extension for VSCode, my text editor of choice (for now...).

Converting the above Java `validateDogName` method to Golang will produce something like:
```golang
func validateDogName(name string) (bool, error) {
    if containsSymbols(name) {
        return false, errors.New("dog cannot have symbols in their name")
    }

    if len(name) > 100 {
        return false, errors.New("who has a name for a dog that long")
    }

    return true, nil
}
```
If you have a Go method that returns the `error` interface, then gotests will generate a test that look like this:
```golang
func Test_validateDogName(t *testing.T) {
    type args struct {
        name string
    }
    tests := []struct {
        name    string
        args    args
        want    bool
        wantErr bool
    }{
        name: "Test error was thrown for dog name with symbols",
        args: args{
            name: "GoodestBoy#1",
        },
        want: false,
        wantErr: true,
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := validateDogName(tt.args.name)
            if (err != nil) != tt.wantErr {
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

From the above we are limited to what error we can assert for, here *any* error returned will pass the test. This is equivalent to using `@Test(expected=Exception.class)` in JUnit! But there is another way...

## Modifying the Generated Test

We only need to make a few simple changes to the generated test to give us the ability to assert on test error message...

{{<highlight go "hl_lines=9 16 21" >}}
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
{{< / highlight >}}

From the above there are three highlighted changes, let's go over them individually:

1. `wantErr error` 
  - we are changing this from `bool` so that we can make a comparison against the error returned from the function
1. `wantErr: errors.New("dog cannot have symbols in their name"),`
  - this is the error struct that we are expecting
1. `if tt.wantErr != nil && !reflect.DeepEqual(err, tt.wantErr) {`
  - check to make sure the test is expected an error, if so then compare it against the returned error

Point 3 provides additional support if there was a test case that did not expect an error. Note how `wantErr` is omitted entirely from the test case below.
```golang
{
    name: "Should return true for valid dog name",
    args: args{
        name: "Benedict Cumberland the Sausage Dog",
    },
    want: true,
}
```

## Customising Gotests Generated Test 
Gotests gives us the ability to provide our own templates for generating tests, and can easily be integrated into your text editor of choice. I'll show you how this can be done in VSCode.

1. Check out gotests and copy the templates directory to a place of your choosing
  - `git clone https://github.com/cweill/gotests.git`
  - `cp -R gotests/internal/render/templates ~/scratch/gotests`

2. Overwrite the contents of function.tmpl with [the contents of this Gist](https://gist.github.com/jdheyburn/978e7b84dc9c197bcdd41afece2edab5)

3. Add the following setting to VSCode's settings.json
  - `"go.generateTestsFlags": ["--template_dir=~/scratch/templates"]` 

Once you have done that, future tests will now generate with stricter error testing! {{<emoji ":tada:" >}}

# Closing

I understand that the recommendations above will make your code more fragile, as the code is subject to any changing of the error message of say a downstream library. However for myself, I prefer to write tests that are strict and minimalise the chance of other errors contaminating tests.

I also understand that GoodestBoy#1 is probably a valid name for a dog! {{<emoji ":dog:" >}}
