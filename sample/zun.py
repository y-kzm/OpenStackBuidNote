from keystoneauth1 import loading
from keystoneauth1 import session
from zunclient import client

loader = loading.get_plugin_loader('password')
auth = loader.load_from_options(
                     auth_url='http://controller:5000/v3',
                     username='admin',
                     password='0ta29SourC3',
                     project_name='admin',
                     user_domain_name='Default',
                     project_domain_name='Default')

sess = session.Session(auth=auth)
zun = client.Client(1, session=sess)

print(zun.containers.list())
zun.containers.run(name="my-container", image='cirros', cpu=0.5, nets=[{'network': 'selfservice'}], host='compute2')

