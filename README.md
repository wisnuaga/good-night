# Good Night

## Description
Good Night is the API service for managing user sleep records and supports follow/unfollow features for any user who wants to see their followee's sleep records.

## Onboarding and Development Guide

### Prerequisite

- [Install git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [Install docker](https://docs.docker.com/desktop/)
- [Install docker-compose](https://docs.docker.com/compose/install/)
- [Install RVM](https://rvm.io/rvm/install)

### Setup

- Clone this repo
  ```sh
  git@github.com:wisnuaga/good-night.git
  ```

- Install Ruby 3.2.2
  ```sh
  rvm install ruby-3.1.4
  ```

- Create good-night gemset
  ```sh
  rvm 3.1.4@good-night --create
  ```

- Setup Bundler
  ```sh
  gem install bundler
  bundle install
  ```

- Setup environment variables
  ```sh
  cp env.sample .env
  ```

## Database Schema

<details>
  <summary>Database Schema</summary>

![schema.png](docs/database/schema.png)

</details>

### Setup Database

- Run `rake db:create`
- Run `rake db:migrate`
- Run `rake db:seed`

**Notes**: Due to unsupported user registration yet, you can add more users in [seeds.rb](db/seeds.rb)

## Request Flows, Endpoints, and Dependencies

#### Endpoints
- [API Documentation](docs/api/api.md)

#### Stateful Dependencies
- PostgreSQL
- Redis

#### Test Documentation
- [API Test Documentation](https://docs.google.com/document/d/1qnj4F4YYZ-npfZb1fwZpAaSv1VqA7xot4LzgpYB3s6A/edit?usp=sharing)
