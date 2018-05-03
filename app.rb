class App < Sinatra::Base
	enable:sessions
	require_relative 'module.rb'

	get '/' do
		db = SQLite3::Database.new("./database/db.sqlite")
		id = session[:yoursession]
		name = db.execute("SELECT name FROM User WHERE id=?",id)
		#if session[:yoursession]!=nil
			slim(:main,locals:{session:id,name:name})
		#else
		#	slim(:main,locals:{id:id})
		#end
	end

	get '/log_in' do
		slim(:log_in)
	end

	post '/logged_in' do
		username = params["username"]
		password = params["password"]
		db = SQLite3::Database.new("./database/db.sqlite") #ej module
		db = connect() #module
		name = db.execute("SELECT name FROM User WHERE name=?",username)
		puts name
		if name.size != 0			
			name = name[0][0]
			check = db.execute("SELECT password FROM User WHERE name=?",username)
			check = check[0][0]
			p check
			check = BCrypt::Password.new(check)
			p password
			if check == password  
				session[:yoursession] = db.execute("SELECT id FROM User WHERE name=?",username)
				redirect("/")
			else
				puts "fel användarnamn eller lösenord"
				redirect("/")
			end
		else
			puts "användarnamn finns inte"
			redirect("/")
		end
	end

	get '/register' do
		slim(:register)
	end

	post '/registered' do
		username = params["username"]
		password = params["password"]
		password = BCrypt::Password.create(password)
		# db = SQLite3::Database.new("./database/db.sqlite")
		db = connect()
		db.execute("INSERT INTO User (name,password) VALUES (?,?)", [username, password])
		account = db.execute("SELECT id FROM User WHERE name=?", [username])
		db.execute("INSERT INTO Balance (kr,user_id) VALUES (0,?)", [account])
		redirect("/")
	end

	get '/log_out' do
		session[:yoursession] = nil
		redirect("/")
	end

	post '/add' do
		product = params["produkt"]
		user = session[:yoursession]
		#db = SQLite3::Database.new("./database/db.sqlite")
		db = connect()
		product = db.execute("SELECT id FROM Item WHERE name=?", [product])
		db.execute("INSERT INTO Shoppinglist (user_id,item_id) VALUES (?,?)", [user, product])
		redirect("/")
	end

	get '/account' do
		user = session[:yoursession]
		#db = SQLite3::Database.new("./database/db.sqlite")
		db = connect()
		name = db.execute("SELECT name FROM User WHERE id=?", [user])
		if name.size != 0
			name = name[0][0]
			kr = db.execute("SELECT kr FROM Balance WHERE user_id=?", [user])
			if kr.size != 0
				kr = kr[0][0]
			else
				kr = 0
			end
			item = []
			cost = []
			items_id = db.execute("SELECT item_id FROM Shoppinglist WHERE user_id=?", [user])
			items_id.each do |item_id|
				item << db.execute("SELECT name FROM Item WHERE id=?", [item_id])[0][0]
				cost <<	db.execute("SELECT cost FROM Item WHERE id=?", [item_id])[0][0]
			end
			puts "kostnader #{cost}"
			i = 0
			sum = 0
			while cost.length > i
				sum = sum + cost[i].to_i
				i += 1
				p sum
			end
			orders = db.execute("SELECT order_id FROM Ordered WHERE user_id=?", [user]).flatten
			slim(:account,locals:{name:name,kr:kr,item:item,cost:cost,sum:sum,orders:orders})
		else
			redirect("/")
		end
		#kanske lägga till en funktion att ta bort saker ur shoppingkorgen.
	end

	post '/add_money' do
		amount = params["amount"]
		user = session[:yoursession]
		#db = SQLite3::Database.new("./database/db.sqlite")
		db = connect()
		if amount.size != 0
			amount = params["amount"].to_f
			balance = db.execute("SELECT kr FROM Balance WHERE user_id=?", [user])[0][0]
			balance = balance.to_i
			new_balance = amount + balance
			db.execute("UPDATE Balance SET kr=? WHERE user_id=?", [new_balance,user])
			redirect("account")
		else
			redirect("account")
		end
	end

	post '/buy' do
		user = session[:yoursession]
		sum = params["sum"].to_i
		#db = SQLite3::Database.new("./database/db.sqlite")
		db = connect()
		shoppinglist = db.execute("SELECT item_id FROM Shoppinglist WHERE user_id=?", [user]).flatten
		if shoppinglist.size != 0
			order_number = rand(100000..999999)
			balance = db.execute("SELECT kr FROM Balance WHERE user_id=?", [user])[0][0]
			balance -= sum
			if balance < 0
				redirect("/account")
			else
				db.execute("UPDATE Balance SET kr=? WHERE user_id=?", [balance,user])
				shoppinglist.each do |item_id|
					db.execute("INSERT INTO Contains (item_id,order_id) VALUES(?,?)", [item_id,order_number])
				end
				db.execute("INSERT INTO Ordered (user_id,order_id) VALUES(?,?)", [user,order_number])
				db.execute("DELETE FROM Shoppinglist WHERE user_id=?", [user])
			end
		else
			redirect("/account")
		end
		redirect("/account")
	end

	post '/order' do
		order = params["order"]
		p order
		user = session[:yoursession]
		#db = SQLite3::Database.new("./database/db.sqlite")
		db = connect()
		items = db.execute("SELECT item_id FROM Contains WHERE order_id=?", [order]).flatten
		items.each do |item|
			db.execute("INSERT INTO Shoppinglist (user_id,item_id) VALUES(?,?)", [user,item])
		end
		db.execute("DELETE FROM Contains WHERE order_id=?", [order])
		db.execute("DELETE FROM Ordered WHERE order_id=?", [order])
		redirect("/account")
	end

	post '/remove_item' do
		item_name = params["item"]
		p item_name
		#db = SQLite3::Database.new("./database/db.sqlite")
		db = connect()
		item_id = db.execute("SELECT id from Item WHERE name=?", [item_name]).flatten
		p item_id
		db.execute("DELETE FROM Shoppinglist WHERE item_id=? LIMIT 1", [item_id[0]])
		redirect("/account")
	end

end           
