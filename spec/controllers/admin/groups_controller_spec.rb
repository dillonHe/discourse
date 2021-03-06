require 'spec_helper'

describe Admin::GroupsController do

  before do
    @admin = log_in(:admin)
  end

  it "is a subclass of AdminController" do
    (Admin::GroupsController < Admin::AdminController).should == true
  end

  it "produces valid json for groups" do
    group = Fabricate.build(:group, name: "test")
    group.add(@admin)
    group.save

    xhr :get, :index
    response.status.should == 200
    ::JSON.parse(response.body).keep_if{|r| r["id"] == group.id}.should == [{
      "id"=>group.id,
      "name"=>group.name,
      "user_count"=>1,
      "automatic"=>false,
      "alias_level"=>0,
      "visible"=>true
    }]
  end

  it "is able to refresh automatic groups" do
    Group.expects(:refresh_automatic_groups!).returns(true)

    xhr :post, :refresh_automatic_groups
    response.status.should == 200
  end

  context '.destroy' do
    it "returns a 422 if the group is automatic" do
      group = Fabricate(:group, automatic: true)
      xhr :delete, :destroy, id: group.id
      response.status.should == 422
      Group.where(id: group.id).count.should == 1
    end

    it "is able to destroy a non-automatic group" do
      group = Fabricate(:group)
      xhr :delete, :destroy, id: group.id
      response.status.should == 200
      Group.where(id: group.id).count.should == 0
    end
  end

  context '.create' do
    let(:usernames) { @admin.username }

    it "is able to create a group" do
      xhr :post, :create, group: {
        usernames: usernames,
        name: "bob"
      }

      response.status.should == 200

      groups = Group.where(name: "bob").to_a

      groups.count.should == 1
      groups[0].usernames.should == usernames
      groups[0].name.should == "bob"
    end

    it "strips spaces from group name" do
      lambda {
        xhr :post, :create, group: {
          usernames: usernames,
          name: " bob "
        }
      }.should_not raise_error()
      Group.where(name: "bob").count.should == 1
    end
  end

  context '.update' do
    let (:group) { Fabricate(:group) }

    it "is able to update group members" do
      user1 = Fabricate(:user)
      user2 = Fabricate(:user)

      xhr :put, :update, id: group.id, name: 'fred', group: {
            name: 'fred',
            usernames: "#{user1.username},#{user2.username}"
          }

      group.reload
      group.users.count.should == 2
      group.name.should == 'fred'
    end

    context 'incremental' do
      before do
        @user1 = Fabricate(:user)
        group.add(@user1)
        group.reload
      end

      it "can make incremental adds" do
        user2 = Fabricate(:user)
        xhr :patch, :update, id: group.id, changes: {add: user2.username}
        response.status.should == 200
        group.reload
        group.users.count.should eq(2)
      end

      it "succeeds silently when adding non-existent users" do
        xhr :patch, :update, id: group.id, changes: {add: "nosuchperson"}
        response.status.should == 200
        group.reload
        group.users.count.should eq(1)
      end

      it "can make incremental deletes" do
        xhr :patch, :update, id: group.id, changes: {delete: @user1.username}
        response.status.should == 200
        group.reload
        group.users.count.should eq(0)
      end

      it "succeeds silently when removing non-members" do
        user2 = Fabricate(:user)
        xhr :patch, :update, id: group.id, changes: {delete: user2.username}
        response.status.should == 200
        group.reload
        group.users.count.should eq(1)
      end

      it "cannot patch automatic groups" do
        auto_group = Fabricate(:group, name: "auto_group", automatic: true)

        xhr :patch, :update, id: auto_group.id, changes: {add: "bob"}
        response.status.should == 403
      end
    end
  end
end
