module VirtualBox
  # Represents guest properties which can be read and set per virtual
  # machine as long as the guest additions are running in the VM.
  #
  # A number of properties are predefined by VirtualBox for retrieving
  # information about the VM such as operating system, guest additions
  # version, users currently logged in, network statistics (including ip
  # addresses), and more. For more information, read the Guest Properties
  # section under the Guest Additions chapter (currently chapter 4) in
  # the VirtualBox manual.
  #
  # Guest Properties on a Virtual Machine
  #
  # Setting a guest property on a virtual machine is easy. All {VM} objects
  # have a `guest_property` relationship which is just a simple ruby hash,
  # so you can treat it like one! Once the data is set, simply saving the VM
  # will save the guest property. An example below:
  #
  #     vm = VirtualBox::VM.find("FooVM")
  #     vm.guest_property["/Foo/Bar"] = "yes"
  #     vm.save
  #
  # Now, let's say you open up the VM again some other time:
  #
  #     vm = VirtualBox::VM.find("FooVM")
  #     puts vm.guest_property["/Foo/Bar"]
  #
  # It acts just like a hash!
  #
  class GuestProperty < Hash
    include AbstractModel::Dirty

    attr_accessor :parent
    attr_reader :interface

    class << self
      # Populates a relationship with another model.
      #
      # **This method typically won't be used except internally.**
      #
      # @return [Array<GuestProperty>]
      def populate_relationship(caller, interface)
        data = new(caller, interface)

        keys, values, timestamps, flags  = interface.enumerate_guest_properties
        keys.each_with_index do |key, index|
          data[key] = values[index]
        end

        data.clear_dirty!
        data
      end

      # Saves the relationship. This simply calls {#save} on every
      # member of the relationship.
      #
      # **This method typically won't be used except internally.**
      def save_relationship(caller, data)
        data.save
      end
    end

    # Initializes a guest property object.
    #
    # @param [Hash] data Initial attributes to populate.
    def initialize(parent, interface)
      @parent = parent
      @interface = interface
    end

    # Set a guest property key-value pair. Overrides ruby hash implementation
    # to set dirty state. Otherwise, behaves the same way.
    def []=(key,value)
      set_dirty!(key, self[key], value)
      super
    end

    # Saves guest properties. This method does the same thing for both new
    # and existing guest properties, since virtualbox will overwrite old data or
    # create it if it doesn't exist.
    def save
      changes.each do |key, value|
        unless virtualbox_key?(key)
          interface.set_guest_property_value(key.to_s, value[1].to_s)

          clear_dirty!(key)

          if value[1].nil?
            # Remove the key from the hash altogether
            hash_delete(key.to_s)
          end
        end
      end
    end

    # Alias away the old delete method so its still accessible somehow
    alias :hash_delete :delete

    # Deletes the specified extra data.
    #
    # @param [String] key The extra data key to delete
    def delete(key)
      unless virtualbox_key?(key)
        interface.set_guest_property_value(key.to_s, nil)
        hash_delete(key.to_s)
      end
    end

    # Determine if a key is one set by VirtualBox
    #
    # **This method typically won't be used except internally.**
    def virtualbox_key?(key)
      key =~ /^\/VirtualBox/
    end
  end
end
