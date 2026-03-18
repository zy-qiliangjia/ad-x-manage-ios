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

# 首页数据 横坐标 改成 日期

# 点击广告-对应的账号列表有个需要修改预算&开关操作

# 功能调整
- 广告页面层级 上面的 账号，推广系列，广告组，广告 可以点击切换
- 从账号点进去的获取当前账号/推广系列/广告组/广告
- 从顶部点进去的获取全部

# 功能完善-登陆成功后-进入首页-获取首页相关数据
- 时间范围默认 近7天
- 通过基础报表 获取当前账号下授权所有的广告主的 消耗，总点击，总展示，总转化 相关指标进行汇总

消耗参考文档：https://business-api.tiktok.com/portal/docs?id=1738864915188737
维度：https://business-api.tiktok.com/portal/docs?id=1751443956638721
指标：https://business-api.tiktok.com/portal/docs?id=1751443967255553


# 功能完善 - 下方广告切换-对应广告账号，广告系列，广告组，广告 点击需要数据
- 当前报错，需要 前后端同步变更支持
- 样式参考图片
- 功能调整 相关后端sql 变动，帮我记录到文档 docs/目录下
- 支持日期筛选 ， 右上角 需要展示更新时间


帮我测试下ios首页 相关功能，使用 zhouyang@qiliangjia.com 密码：aa123456
这个账号授权过正式的 token, 可以调用tiktok接口，如果有错误，帮我检查并修复

# 广告tab 切换失败 需要完善
- error:  GET http://localhost:8080/api/v1/campaigns?page=1&page_size=20
⬅️ 404 http://localhost:8080/api/v1/campaigns?page=1&page_size=20
   Body: 404 page not found

# 功能新增-首页支持时间筛选
- 参考图片

# 获取首页广告数据统计错误-需要修复
	WARN	stats/service.go:137	stats: get report failed	{"platform": "tiktok", "advertiser_id": "7600228996734910465", "error": "tiktok get report error 40001: Permission error: The access token lacks the required scope for endpoint '/report/advertiser/get/(method=POST)'. Please first check if the request method is correct then ask the user to generate a new access token and reauthorize your API App with the necessary API scopes."}
1. 能否改用 广告主，批量一次获取
2. 授权token 不用加密处理 
3. 日志输出所有sql&请求明细


# 授权后-第三方授权平台 refresh_token 保存为空a
---
20260318

# 首页数据汇总(4个指标)-调整
- 通过接口拉取，指定维度&指标，获取当前对应平台的所有 advertiser_id
- 结果缓存15分钟
- 指标对应（取total_metrics）：
    spend： 总消耗
    conversion： 转化
    clicks：点击
    impressions： 展示

tikto请求示例：
```
https://business-api.tiktok.com/open_api/v1.3/report/integrated/get?page=1&data_level=AUCTION_ADVERTISER&report_type=BASIC&dimensions=[%22advertiser_id%22]&metrics=[%22clicks%22,%22spend%22,%22conversion%22,%22cost_per_conversion%22,%22impressions%22]&page_size=1000&start_date=2026-02-17&end_date=2026-03-17&enable_total_metrics=true&advertiser_ids=[%227582793237962817552%22]
```
返回：
```
{
    "code": 0,
    "message": "OK",
    "request_id": "202603181050188307158386EE8B8893B7",
    "data": {
        "page_info": {
            "total_number": 1,
            "page_size": 1,
            "page": 1,
            "total_page": 1
        },
        "list": [
            {
                "dimensions": {
                    "advertiser_id": "7582793237962817552"
                },
                "metrics": {
                    "currency": "USD",
                    "impressions": "1017",
                    "conversion": "0",
                    "spend": "5.57",
                    "clicks": "68",
                    "advertiser_id": "7582793237962817552",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00"
                }
            }
        ],
        "total_metrics": {
            "currency": "-",
            "impressions": "1017",
            "conversion": "0",
            "spend": "5.57",
            "clicks": "68",
            "advertiser_id": "-",
            "timezone": "-",
            "cost_per_conversion": "0.00"
        }
    }
}
```


提按调整- 拉取数据有接口限制频率问题，1s 10次
单次最多只支持5个广告主，需要将广告主拆分进行拉取, 将拉取到的进行保存



# ios端下方广告标签页调整
背景：当前点击下方广告 tab,首先出现的是账号列表，现在需要在每个账号列表上加入数据&汇总相关，支持时间选择切换
- 账号列表每个账号加入指标， 消耗，点击，展示，转化，cpa,日预算
- 支持自定义日期筛选，日期跨度最多30天
- 通过接口拉取-并缓存，接口有频率限制，每次请求支持广告主最多5个，需要拆分
- 数据未拉取到的显示0
- 接口请求示例(tiktok平台),读取list advertiser_id 进行匹配
    "conversion": "转化",
    "cost_per_conversion": "0.00",
    "spend": "消耗",
    "currency": "USD",
    "clicks": "点击",
    "impressions": "展示",
    "skan_click_time_cost_per_conversion": "cpa",
    "advertiser_id": "7582793237962817552",
- 支持汇总
```
https://business-api.tiktok.com/open_api/v1.3/report/integrated/get?page=1&data_level=AUCTION_ADVERTISER&report_type=BASIC&dimensions=[%22advertiser_id%22]&metrics=[%22clicks%22,%22spend%22,%22conversion%22,%22cost_per_conversion%22,%22impressions%22,%22skan_click_time_cost_per_conversion%22]&page_size=1000&start_date=2026-02-17&end_date=2026-03-17&enable_total_metrics=true&advertiser_ids=[%227582793237962817552%22,%227363465639475871761%22,%227363465671117750289%22]
```
- 返回示例
```
{
    "code": 0,
    "message": "OK",
    "request_id": "202603181152129F75FEDB727D90477891",
    "data": {
        "list": [
            {
                "dimensions": {
                    "advertiser_id": "7582793237962817552"
                },
                "metrics": {
                    "conversion": "0",
                    "cost_per_conversion": "0.00",
                    "spend": "5.57",
                    "currency": "USD",
                    "clicks": "68",
                    "impressions": "1017",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "advertiser_id": "7582793237962817552",
                    "timezone": "Asia/Singapore"
                }
            }
        ],
        "page_info": {
            "page": 1,
            "page_size": 1,
            "total_number": 1,
            "total_page": 1
        },
        "total_metrics": {
            "conversion": "0",
            "cost_per_conversion": "0.00",
            "spend": "5.57",
            "currency": "-",
            "clicks": "68",
            "impressions": "1017",
            "skan_click_time_cost_per_conversion": "0.00",
            "advertiser_id": "-",
            "timezone": "-"
        }
    }
}
```

# ios 首页汇总数据调整-通过接口拉取


# ios 底部 账号 tab 切换的账号列表-不需要点击跳转能力，只需要展示列表即可


# ios端&后端首页数据汇总(4个指标)-调整
- ios首页当前4个指标 改为 总消耗，总点击，总展示，总转化
- 后端通过接口拉取，指定维度&指标，获取当前对应平台的所有 advertiser_id，需要拆分，每次最多支持5个 5个广告主，日期范围跨度不允许超过30天
- 读取数据指标接口有频率限制 每秒10次
- 默认日期给最近30天
- 拉取到的结果缓存15分钟
- 指标对应（取total_metrics）：
    spend： 总消耗
    conversion： 转化
    clicks：点击
    impressions： 展示

tikto请求示例：
```
https://business-api.tiktok.com/open_api/v1.3/report/integrated/get?page=1&data_level=AUCTION_ADVERTISER&report_type=BASIC&dimensions=[%22advertiser_id%22]&metrics=[%22clicks%22,%22spend%22,%22conversion%22,%22cost_per_conversion%22,%22impressions%22]&page_size=1000&start_date=2026-02-17&end_date=2026-03-17&enable_total_metrics=true&advertiser_ids=[%227582793237962817552%22]
```
返回：
```
{
    "code": 0,
    "message": "OK",
    "request_id": "202603181050188307158386EE8B8893B7",
    "data": {
        "page_info": {
            "total_number": 1,
            "page_size": 1,
            "page": 1,
            "total_page": 1
        },
        "list": [
            {
                "dimensions": {
                    "advertiser_id": "7582793237962817552"
                },
                "metrics": {
                    "currency": "USD",
                    "impressions": "1017",
                    "conversion": "0",
                    "spend": "5.57",
                    "clicks": "68",
                    "advertiser_id": "7582793237962817552",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00"
                }
            }
        ],
        "total_metrics": {
            "currency": "-",
            "impressions": "1017",
            "conversion": "0",
            "spend": "5.57",
            "clicks": "68",
            "advertiser_id": "-",
            "timezone": "-",
            "cost_per_conversion": "0.00"
        }
    }
}
```

# ios 端需要支持调整预算
背景： 当前点击下方广告(tab),在对应的账号下面操作预算，提交报错
- 需要前后端都支持
- 修改的预算保存到本地 
- 文档参考 https://business-api.tiktok.com/portal/docs?id=1739939050770434

# ios端 点击下方tab 切换到 广告组系列，需要添加数据
- 每个广告组显示消耗，点击，展示，转化，cpa
- 包含暂停投放,调整预算操作
- 通过调用接口获取 相关数据 -进行本地缓存 30分钟
- 调用示例： tiktok 平台
- 调用示例
```
https://business-api.tiktok.com/open_api/v1.3/report/integrated/get?page=1&data_level=AUCTION_ADGROUP&report_type=BASIC&dimensions=[%22adgroup_id%22]&metrics=[%22clicks%22,%22spend%22,%22conversion%22,%22cost_per_conversion%22,%22impressions%22,%22skan_click_time_cost_per_conversion%22]&page_size=1000&start_date=2026-02-17&end_date=2026-03-17&enable_total_metrics=true&advertiser_ids=[%227582793237962817552%22,%227363465639475871761%22,%227363465671117750289%22]
```
- 第三方返回示例
```
{
    "code": 0,
    "message": "OK",
    "request_id": "20260318170451CD2C8CC3E3F93F7E0AA3",
    "data": {
        "total_metrics": {
            "conversion": "0",
            "clicks": "68",
            "advertiser_id": "-",
            "spend": "5.57",
            "impressions": "1017",
            "skan_click_time_cost_per_conversion": "0.00",
            "timezone": "-",
            "cost_per_conversion": "0.00",
            "currency": "-"
        },
        "list": [
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "68",
                    "advertiser_id": "7582793237962817552",
                    "spend": "5.57",
                    "impressions": "1017",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1856814974955537"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1856737075237938"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1854823618793569"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1854818795428065"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1853626498542626"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1852919338637538"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1852912055994418"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1852852587134273"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1852851763493969"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1852676475048993"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1852650384568545"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1852570104836145"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1852450527579170"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7582793237962817552",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Singapore",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1852372418732145"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7363465671117750289",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Shanghai",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1816965017385041"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7363465639475871761",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Shanghai",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1803543721260081"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7363465639475871761",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Shanghai",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1803458949522450"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7363465639475871761",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Shanghai",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1803455200980018"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7363465639475871761",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Shanghai",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1803362186626113"
                }
            },
            {
                "metrics": {
                    "conversion": "0",
                    "clicks": "0",
                    "advertiser_id": "7363465639475871761",
                    "spend": "0.00",
                    "impressions": "0",
                    "skan_click_time_cost_per_conversion": "0.00",
                    "timezone": "Asia/Shanghai",
                    "cost_per_conversion": "0.00",
                    "currency": "USD"
                },
                "dimensions": {
                    "adgroup_id": "1803360662064177"
                }
            }
        ],
        "page_info": {
            "page": 1,
            "page_size": 20,
            "total_number": 20,
            "total_page": 1
        }
    }
}
```


# ios端 点击下方tab 切换到 广告组系列
- 每行广告组去掉日预算，操作暂停按钮放到cpa 后面，不然显得每行数据格式不齐



# ios端 下方tab 切换到广告，不通过点击账号列表进入后，直接点击日期下方的广告组相关布局需要和从账号点进去的保持一致

# ios端 下方tab 切换到广告，不通过点击账号列表进入后，直接点击日期下方的广告组相关布局需要和从账号点进去的保持一致
