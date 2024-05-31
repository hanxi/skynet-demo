local M = {}

local role_mt = { __index = M }
function M.new(uid, db_data)
	local obj = {
		uid = uid,
		db_data = db_data,
	}
	return setmetatable(obj, role_mt)
end

function M:get_role_id()
	return self.uid
end

function M:get_sign_cnt()
	return self.db_data.sign_cnt or 0
end

function M:sign()
	self.db_data.sign_cnt = self:get_sign_cnt() + 1
	log.info("sign ok. uid:", self.uid, ", sign_cnt:", self:get_sign_cnt())
end

function M:get_dirty_data()
	return self.db_data
end

return M
