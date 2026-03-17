我想要做一个广告聚合平台ios 版，主要用来管理 tiktok & kwai 平台的广告，预算，报表相关的，需要先准备哪些东西？



后端使用 go (gin) + mysql + redis 配置文件使用 .env 模式


帮我整理合规完整的 claude.md 输出到文档，使用中文


---


背景：我通过对应的应用授权后获取当前账号下数据,便于放便广告主对广告进行管理

大概流程是 通过邮箱&密码登陆后 进入到选择平台->选择对应平台后->获取当前平台下的账号->没有的话点击右上角去授权-〉授权完成后 拉取当前账号下的所有账号列表(需要显示名字&ID，金额相关)-金额默认关闭，点击查看，通过api 实时获取-〉点击账号行->进入到另一个页面->显示当前账号下的推广系列/广告组两个tab切换
1. 登陆
2. 选择平台
3. 进入到对应的平台账号列表/或授权(支持账号搜索和分页-下拉)
    - 授权完成后自动拉取该账号下的所有广告主，推广系列，广告组，广告平台(保存到本地)
4. 账号上面有余额按钮 点击查看-实时查询当前账号的余额
5. 点击账号列表进入新页面(推广系列/广告组/广告)，3个tab 可切换
6. 每行推广系列默认显示名称 ，ID，投放状态，消耗， 预算，上面有个操作按钮->点击弹出显示（修改预算，开启/暂停投放， 点击当前行->跳转到对应的广告组
7. 点击广告组tab->显示当前广告列表（可操作修改预算，暂停/开启投放）点击广告组跳转到对应到广告
8. 点击广告tab 显示广告列表（包含id,名称，状态 &广告组名称，id） - 支持 ID 和名称搜所
样式高大上一点,
基于背景和流程，帮我重新分析下，需要ios端和后端同时开发


需要完整的 账号，推广系列，广告组，广告，能看到对应的报表和操作推广系列的修改预算，同当前tiktok 平台 划分 推广系列，广告组，广告


帮我输出完整的方案及sql,


 curl -s -X POST "http://localhost:8080/api/v1/advertisers/1/sync" \
    -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJlbWFpbCI6Inpob3V5YW5nQHFpbGlhbmdqaWEuY29tIiwiZXhwIjoxNzczNjM0Mjk0LCJpYXQiOjE3NzM2MjcwOTQsImp0aSI6IjY0YjA5Yzk4LTFhYWUtNDk3Mi05NDk3LWFlOThhMzAwYTc5MSJ9.EJW8UNgnQ08AiXKGBgNsQ79LLOZWY3DQHOVzwfxi6d0" \
    -H "Content-Type: application/json"


我想在登陆后读取当前授权账号的下的全部 系列，广告组，广告，另外从数据上看 获取token时，并没有open_user_id



ios 版帮我调整交互和功能，参考 [text](ad-manager-mobile.html)交互， 可以使用 frontend-desig 帮我设计下，
如果用 mysql 相关改动，帮我把改动输出到docs下文档里面，相关功能重新梳理，并同步到 claude.md 里面

帮我把 账号 zhouyang@qiliangjia.com 的密码改成 aa123456
我现在登陆不进去


1. 你用 test1@qiliangjia.com 密码：aa123456 注册/登陆测试一下整个流程
2. 

openspec 
# 样式和布局功能调整 
- 参考 /Users/edy/data/project/42-ad-x-manage-ios/ad-manager-mobile.html 交互和功能，对ios 版本进行调整
- 如果有sql 变更，把相关sql的变更语句记录到 docs/ 文档下
- 保证功能的实现和交互正常，可以使用 frontend-design skills 进行设计
- 界面好看点
- 中间有任何问题可以问我
- 当前主要考虑 titok平台

# 账号tab 帮我调整下 
- 去除 倒计时
- id 只显示后几位
- 感觉页面隔一段时间自己跳一下，不需要这个结果