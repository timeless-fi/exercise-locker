# Exercise locker

Enables offering a better discount when exercising oLIT options and immediately locking it for veLIT.

## Installation

To install with [Foundry](https://github.com/gakonst/foundry):

```
forge install timeless-fi/exercise-locker
```

## Local development

This project uses [Foundry](https://github.com/gakonst/foundry) as the development framework.

### Dependencies

```
forge install
```

### Compilation

```
forge build
```

### Testing

```
forge test -f mainnet
```

### Contract deployment

Please create a `.env` file before deployment. An example can be found in `.env.example`.

#### Dryrun

```
forge script script/Deploy.s.sol -f [network]
```

### Live

```
forge script script/Deploy.s.sol -f [network] --verify --broadcast
```