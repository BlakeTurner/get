require 'spec_helper'

if !defined?(ActiveRecord::Base)
  puts "** require 'active_record' to run the specs in #{__FILE__}"
else
  ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

  ActiveRecord::Migration.suppress_messages do
    ActiveRecord::Schema.define(:version => 0) do
      create_table(:employers, force: true) {|t| t.string :name }
      create_table(:users, force: true) {|t| t.string :first_name; t.string :last_name; t.references :employer; }
      create_table(:sports_cars, force: true) {|t| t.string :make; t.references :employer; }
    end
  end

  module GetSpec
    class Employer < ActiveRecord::Base
      has_many :users
      has_many :sports_cars
    end

    class User < ActiveRecord::Base
      belongs_to :employer
    end

    class SportsCar < ActiveRecord::Base
      belongs_to :employer
    end
  end
end

describe Get do
  let(:last_name) { 'Turner' }
  let(:adapter) { :active_record }

  # Preserve system config for other tests
  before(:all) { @system_config = Get.configuration }
  after(:all) { Get.configuration = @system_config }

  # Reset base config with each iteration
  before { Get.configure { |config| config.adapter = adapter } }
  after do
    GetSpec::User.delete_all
    GetSpec::Employer.delete_all
    Get.reset
  end

  class MyCustomEntity < Horza::Entities::Collection
    def east_london_length
      "#{length}, bruv"
    end
  end

  context 'development_mode' do
    before do
      Get.reset
      Get.configure do |config|
        config.adapter = 'my_adapter'
        config.development_mode = true
      end
    end
    after do
      Get.reset
    end
    it 'sets Horza to development mode' do
      expect(Horza.configuration.development_mode).to be true
    end
  end

  context 'namespaces' do
    before do
      Get.reset
      Get.configure do |config|
        config.adapter = 'my_adapter'
        config.namespaces =  [GetSpec]
      end
    end
    after do
      Get.reset
    end
    it 'sets Horza to development mode' do
      expect(Horza.configuration.namespaces).to eq [GetSpec]
    end
  end

  context '#adapter' do
    context 'when the adapter is set' do
      it 'returns the correct adapter class' do
        expect(Get.adapter).to eq Horza::Adapters::ActiveRecord
      end
    end

    context 'when the adapter is not set' do
      before { Get.reset }
      after { Get.reset }

      it 'throws error' do
        expect { Get.adapter }.to raise_error(Get::Errors::Base)
      end
    end
  end

  context '#reset' do
    before do
      Get.configure do |config|
        config.adapter = 'my_adapter'
      end
      Get.reset
    end
    it 'resets the config' do
      expect(Get.configuration.adapter).to be nil
    end
  end

  context '#run!' do
    context 'singular form' do
      context 'when the record exists' do
        let!(:user) { GetSpec::User.create(last_name: last_name) }

        context 'field in class name' do
          it 'gets the records based on By[KEY]' do
            result = Get::UserById.run!(user.id)
            expect(result.to_h).to eq user.attributes
          end

          it 'returns a dynamically generated response entity' do
            expect(Get::UserById.run!(user.id).is_a?(Horza::Entities::Single)).to be true
          end
        end

        context 'field in parameters' do
          it 'gets the records based on parameters' do
            result = Get::UserBy.run!(last_name: last_name)
            expect(result.to_h).to eq user.attributes
          end

          it 'returns a dynamically generated response entity' do
            expect(Get::UserBy.run!(last_name: last_name).is_a?(Horza::Entities::Single)).to be true
          end
        end
      end

      context 'when the record does not exist' do
        it 'returns nil' do
          expect { Get::UserById.run!(999) }.to raise_error Get::Errors::Base
        end
      end
    end

    context 'ancestry' do
      context 'valid ancestry with no saved parent' do
        let(:user2) { GetSpec::User.create }
        it 'returns nil' do
          expect(Get::EmployerFromUser.run!(user2)).to be nil
        end
      end
    end
  end

  context '#run' do
    context 'singular form' do
      context 'when the record exists' do
        let!(:user) { GetSpec::User.create(last_name: last_name) }

        context 'field in class name' do
          it 'gets the records based on By[KEY]' do
            result = Get::UserById.run(user.id)
            expect(result.to_h).to eq user.attributes
          end

          it 'returns a dynamically generated response entity' do
            expect(Get::UserById.run(user.id).is_a?(Horza::Entities::Single)).to be true
          end
        end

        context 'field in parameters' do
          it 'gets the records based on parameters' do
            result = Get::UserBy.run(last_name: last_name)
            expect(result.to_h).to eq user.attributes
          end

          it 'returns a dynamically generated response entity' do
            expect(Get::UserBy.run(last_name: last_name).is_a?(Horza::Entities::Single)).to be true
          end
        end
      end

      context 'when the record does not exist' do
        it 'returns nil' do
          expect(Get::UserById.run(999)).to eq nil
        end
      end
    end

    context 'plural form' do
      let(:last_name) { 'Turner' }
      let(:match_count) { 3 }
      let(:miss_count) { 2 }

      context 'when records exist' do
        before do
          match_count.times { GetSpec::User.create(last_name: last_name)  }
          miss_count.times { GetSpec::User.create }
        end

        context 'field in class name' do
          it 'gets the records based on By[KEY]' do
            result = Get::UsersByLastName.run(last_name)
            expect(result.length).to eq match_count
          end

          it 'returns a dynamically generated response entity' do
            expect(Get::UsersByLastName.run(last_name).is_a?(Horza::Entities::Collection)).to be true
          end
        end

        context 'field in parameters' do
          it 'gets the records based on parameters' do
            result = Get::UsersBy.run(last_name: last_name)
            expect(result.length).to eq match_count
          end

          it 'returns a dynamically generated response entity' do
            expect(Get::UsersBy.run(last_name: last_name).is_a?(Horza::Entities::Collection)).to be true
          end
        end

        context 'when All' do
          it 'gets all records' do
            result = Get::AllUsers.run
            expect(result.length).to eq match_count + miss_count
          end

          it 'throws an exception if options passed' do
            expect{ Get::AllUsers.run(last_name: last_name) }.to raise_error Get::Errors::OptionsNotPermitted
          end
        end 
      end

      context 'with options' do
        let(:last_name) { 'Turner' }
        let(:match_count) { 20 }
        let(:miss_count) { 7 }

        before do
          match_count.times { GetSpec::User.create(last_name: last_name)  }
          miss_count.times { GetSpec::User.create }
        end

        context 'when limit is passed' do
          it 'limits the records' do
            result = Get::UsersBy.run({ last_name: last_name }, limit: 2)
            expect(result.length).to eq 2
          end
        end

        context 'when offset is passed' do
          it 'offsets the response' do
            result = Get::UsersBy.run({ last_name: last_name }, offset: 5)
            expect(result.length).to eq 15
          end
        end

        context 'when order is passed' do
          it 'orders the response' do
            result = Get::UsersBy.run({ last_name: last_name }, order: { id: :asc })
            ar_result = GetSpec::User.where(last_name: last_name).order('id asc')

            expect(result.first.id).to eq ar_result.first.id
            expect(result.last.id).to eq ar_result.last.id
          end
        end
      end

      context 'when no records exist' do
        it 'returns empty collection' do
          expect(Get::UsersBy.run(last_name: last_name).empty?).to be true
        end
      end
    end

    context 'associations' do
      context 'direct relation' do
        let(:employer) { GetSpec::Employer.create }
        let!(:user1) { GetSpec::User.create(employer: employer) }
        let!(:user2) { GetSpec::User.create(employer: employer) }

        context 'ParentFromChild' do
          it 'returns parent' do
            expect(Get::EmployerFromUser.run(user1).to_h).to eq employer.attributes
          end
        end

        context 'ChildrenFromParent' do
          it 'returns children' do
            result = Get::UsersFromEmployer.run(employer)
            ar_result = GetSpec::User.where(employer_id: employer.id).order('id desc')
            expect(result.first.id).to eq ar_result.first.id
            expect(result.last.id).to eq ar_result.last.id
          end
        end

        context 'invalid ancestry' do
          it 'throws error' do
            expect { Get::UserFromEmployer.run(employer) }.to raise_error Get::Errors::InvalidAncestry
          end
        end

        context 'valid ancestry with no saved childred' do
          let(:employer2) { GetSpec::Employer.create }
          it 'returns empty collection error' do
            expect(Get::UsersFromEmployer.run(employer2).empty?).to be true
          end
        end

        context 'valid ancestry with no saved parent' do
          let(:user2) { GetSpec::User.create }
          it 'returns nil' do
            expect(Get::EmployerFromUser.run(user2)).to be nil
          end
        end
      end

      context 'using via' do
        let(:employer) { GetSpec::Employer.create }
        let(:user) { GetSpec::User.create(employer: employer) }
        let(:sportscar) { GetSpec::SportsCar.create(employer: employer) }

        before do
          employer.sports_cars << sportscar
        end

        it 'returns the correct ancestor (single via symbol)' do
          result = Get::SportsCarsFromUser.run(user, via: :employer)
          expect(result.first.to_h).to eq sportscar.attributes
        end

        it 'returns the correct ancestor (array of via symbols)' do
          result = Get::SportsCarsFromUser.run(user, via: [:employer])
          expect(result.first.to_h).to eq sportscar.attributes
        end
      end

      context 'with options' do
        let(:employer) { GetSpec::Employer.create }
        let(:match_count) { 20 }
        let(:miss_count) { 7 }

        before do
          match_count.times { employer.users << GetSpec::User.create(employer: employer, last_name: last_name) }
          miss_count.times { employer.users << GetSpec::User.create(employer: employer) }
        end

        context 'when conditions are passed' do
          it 'filters response' do
            result = Get::UsersFromEmployer.run(employer.id, conditions: { last_name: last_name })
            expect(result.length).to eq match_count
          end
        end

        context 'when limit is passed' do
          it 'limits response' do
            result = Get::UsersFromEmployer.run(employer.id, conditions: { last_name: last_name }, limit: 5)
            expect(result.length).to eq 5
          end
        end

        context 'when offset is passed' do
          it 'offsets response' do
            result = Get::UsersFromEmployer.run(employer.id, conditions: { last_name: last_name }, offset: 16)
            expect(result.length).to eq match_count - 16
          end
        end

        context 'when order is passed' do
          it 'orders response' do
            result = Get::UsersFromEmployer.run(employer.id, conditions: { last_name: last_name }, order: { id: :asc })
            ar_result = GetSpec::User.where(employer_id: employer.id, last_name: last_name).order('id asc')

            expect(result.first.id).to eq ar_result.first.id
            expect(result.last.id).to eq ar_result.last.id
          end
        end

        context 'when eager_load is passed' do
          it 'behaves as expected' do
            result = Get::UsersFromEmployer.run(employer.id, conditions: { last_name: last_name }, eager_load: true)
            expect(result.length).to eq match_count
          end
        end
      end
    end

    context 'joins' do
      let(:employer) { GetSpec::Employer.create }
      let(:employer2) { GetSpec::Employer.create }
      let(:match_count) { 20 }
      let(:miss_count) { 7 }

      before do
        match_count.times { employer2.users << GetSpec::User.create(employer: employer2) }
        miss_count.times { employer.users << GetSpec::User.create(employer: employer) }
      end

      context 'when no conditions are passed' do
        let(:join_params) do
          {
            on: { employer_id: :id } # field for adapted model => field for join model
          }
        end

        it 'returns match_count + miss_count joines records' do
          result = Get::UsersJoinedWithEmployers.run(join_params)
          expect(result.length).to eq match_count + miss_count
        end
      end

      context 'when conditions are passed' do
        let(:join_params) do
          {
            on: { employer_id: :id }, # field for adapted model => field for join model
            conditions: {
              employers: { id: employer2.id }
            }
          }
        end

        it 'returns match_count joined records' do
          result = Get::UsersJoinedWithEmployers.run(join_params)
          expect(result.length).to eq match_count
        end
      end

      context 'when conditions and fields are passed' do
        let(:join_params) do
          {
            on: { employer_id: :id }, # field for adapted model => field for join model
            conditions: {
              employers: { id: employer2.id }
            },
            fields: {
              users: [:id],
              employers: [{id: :my_employer_id}]
            }
          }
        end

        it 'returns match_count joined records' do
          result = Get::UsersJoinedWithEmployers.run(join_params)
          expect(result.length).to eq match_count
          expect(result.first.my_employer_id).to eq employer2.id
        end
      end

    end
  end
end

describe Get::Builders::AncestryBuilder do
  let(:name) { 'UserFromEmployer' }

  before { Get.configure { |config| config.adapter = :active_record } }
  after { Get.reset }

  subject { Get::Builders::AncestryBuilder.new(name) }

  describe '#class' do
    it 'builds a class that inherits from Get::Db' do
      expect(subject.class.superclass).to eq Get::Db
    end

    it 'correctly assigns class-level variables' do
      [:entity, :query_key, :collection, :store, :target].each do |class_var|
        expect(subject.class.respond_to? class_var).to be true
      end
    end
  end
end

describe Get::Builders::QueryBuilder do
  let(:name) { 'UserFromEmployer' }

  before { Get.configure { |config| config.adapter = :active_record } }
  after { Get.reset }

  subject { Get::Builders::QueryBuilder.new(name) }

  describe '#class' do
    it 'builds a class that inherits from Get::Db' do
      expect(subject.class.superclass).to eq Get::Db
    end

    it 'correctly assigns class-level variables' do
      [:entity, :query_key, :collection, :store, :field].each do |class_var|
        expect(subject.class.respond_to? class_var).to be true
      end
    end
  end
end

describe Get::Parser do
  let(:ancestry_name) { 'UserFromEmployer' }
  let(:query_name) { 'UserFromEmployer' }
  let(:join_name) { 'UsersJoinedWithEmployers' }

  subject { Get::Parser }
  before { Get.configure { |config| config.adapter = :active_record } }
  after { Get.reset }

  describe '#match?' do
    context 'when name is of ancestry type' do
      it 'returns true' do
        expect(subject.new(ancestry_name).match?).to be true
      end
    end

    context 'when name is of query type' do
      it 'returns true' do
        expect(subject.new(query_name).match?).to be true
      end
    end

    context 'when name is of join type' do
      it 'returns true' do
        expect(subject.new(join_name).match?).to be true
      end
    end

    context 'when name is of no type' do
      it 'returns false' do
        expect(subject.new('Blablabla').match?).to be false
      end
    end
  end

  context 'two instances of "By" in class name' do
    it 'throws error' do
      expect { subject.new('UserByInvitedByType') }.to raise_error Get::Errors::InvalidClassName
    end
  end
end
