module Restaurants
  class SerializeAndPersistService
    ALLOWED_RESTAURANT_ATTRIBUTES = [:name, :menus, :description, :phone_number, :email].freeze
    ALLOWED_MENU_ATTRIBUTES = [:name, :menu_items, :description, :is_acive].freeze
    ALLOWED_MENU_ITEM_ATTRIBUTES = [:name, :price, :category, :description, :ingredients, :is_available, :calories, :allergens].freeze

    def initialize(data)
      @data = data
      @menu_item_logs = []
    end
    
    def call
      validate_format_data
      create_restaurants(@data["restaurants"])
      @menu_item_logs
    end

    private 

    def validate_permitted_attributes(data, allowed_attributes, context)
      unpermitted_attributes = data.keys - allowed_attributes.map(&:to_s)
  
      if unpermitted_attributes.any?
        raise ArgumentError.new("Invalid formar Data. Unpermitted #{context} key(s): #{unpermitted_attributes.join(', ')}")
      end
    end

    def validate_format_data      
      raise ArgumentError.new("Invalid data format. It should be a Hash.") unless  @data.is_a?(Hash)
      raise ArgumentError.new("No restaurants found in the give JSON data.") if @data.blank? || !@data['restaurants'].is_a?(Array) || @data["restaurants"].blank?
      
      @data["restaurants"].each do |restaurant| 
        validate_permitted_attributes(restaurant, ALLOWED_RESTAURANT_ATTRIBUTES, "Restaurant")
        restaurant["menus"].each do |menu| 
          validate_permitted_attributes(menu, ALLOWED_MENU_ATTRIBUTES, "Menu")
          menu["menu_items"].each do |menu_item| 
            validate_permitted_attributes(menu_item, ALLOWED_MENU_ITEM_ATTRIBUTES, "MenuItem")
          end
        end
      end
    end
    
    def create_restaurants(restaurants_data)
      restaurants_data.each do |restaurant_data|
        logs = []
        restaurant = Restaurant.new(restaurant_data.except("menus"))

        if restaurant.save
          logs << "Restaurant #{restaurant.name}} successfully created. ID: #{restaurant.id}}"
        else
          logs << "Failed to create Restaurant. #{restaurant.errors.full_messages.join(", ")}"
        end
        
        create_menus(restaurant_data["menus"], restaurant&.id, logs)        
      end
    end

    def create_menus(menus_data, restaurant_id, restaurant_logs)
      menus_data.each do |menu_data|
        logs = restaurant_logs.dup

        if restaurant_id.nil?
          logs << "Failed to create Menu because Restaurant does no exist."
          create_menu_items(menu_data["menu_items"], nil, logs)
        end

        menu = Menu.new(menu_data.except("menu_items").merge(restaurant_id: restaurant_id))

        if menu.save
          logs << "Menu #{menu.name}} successfully created. ID: #{menu.id}}"
        else
          logs << "Failed to create Menu. #{menu.errors.full_messages.join(", ")}"
        end

        create_menu_items(menu_data["menu_items"], menu&.id, logs)        
      end
    end

    def create_menu_items(menu_items_data, menu_id, menu_logs)
      menu_items_data.each do |menu_item_data|
        logs = menu_logs.dup
        if menu_id.nil?
          logs << "Failed to create MenuItem because Menu does no exist."
          set_logs(menu_item_data, logs)
          next
        end

        success = true
        menu_item = MenuItem.find_by_name(menu_item_data["name"])

        if menu_item.present?
          logs << "There's already an menu item with this name."
          logs << "The existing object will be used instead of creating a new one."
        else
          menu_item = MenuItem.new(menu_item_data)
          if menu_item.save
            logs << "MenuItem #{menu_item.name}} successfully created. ID: #{menu_item.id}}"
          else
            logs << "Failed to create MenuItem. #{menu_item.errors.full_messages.join(", ")}"
            success = false
          end
        end  
        
        unless success
          set_logs(menu_item_data, logs) 
          next 
        end
        
        menu_item_menu = MenuItemMenu.new(menu_item_id: menu_item.id, menu_id: menu_id)
        
        begin 
          if menu_item_menu.save
            logs << "Association Menu with MenuItem successfully created."
            success = true
          else
            logs << "Fail to associate Menu with MenuItem. #{menu_item_menu.errors.full_messages.join(", ")}"
            success = false
          end
        rescue ActiveRecord::RecordNotUnique
          logs << "Association Menu with MenuItem alredy exists"
          success = true
        end

        set_logs(menu_item_data, logs, success) 
      end
    end

    def set_logs(menu_item, list_of_logs, success = false)
      @menu_item_logs << {
        success: success,
        menu_item: menu_item,
        logs: list_of_logs
      }
    end
  end
end