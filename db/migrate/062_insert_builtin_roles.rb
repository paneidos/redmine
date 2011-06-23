class InsertBuiltinRoles < ActiveRecord::Migration
  def self.up
    nonmember = Role.new(:name => 'Non member', :position => 0)
    nonmember.send(:attributes=, { :builtin => Role::BUILTIN_NON_MEMBER }, false)
    nonmember.save
    
    anonymous = Role.new(:name => 'Anonymous', :position => 0)
    anonymous.send(:attributes=, { :builtin => Role::BUILTIN_ANONYMOUS }, false)
    anonymous.save
  end

  def self.down
    Role.destroy_all 'builtin <> 0'
  end
end
