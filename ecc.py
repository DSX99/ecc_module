from tinyec import ec
import random
from fastecdsa.curve import Curve
from fastecdsa.point import Point

def inverse(a,p):
    return pow(a,p-2,p)

def point_add_affine(p1_x,p1_y,p2_x,p2_y,a,p):
    if p1_x == None:
        return p2_x,p2_y
    if p2_x == None:
        return p1_x,p1_y
    m = (p2_y-p1_y)*(inverse(p2_x-p1_x,p))%p
    p3_x = (m**2-p1_x-p2_x)%p
    p3_y = (-(p1_y+m*(p3_x-p1_x)))%p

    return (p3_x,p3_y)

def point_add(p1_x,p1_y,p2_x,p2_y,a,p):
    if p1_x == 0:
        return p2_x,p2_y
    if p2_x == 0:
        return p1_x,p1_y
    #here i define z=1, but for chained operations we should carry z between all operations
    p1_z = 1
    p2_z = 1
    u1 = (p1_x*p2_z**2)%p
    u2 = (p2_x*p1_z**2)%p
    s1 = (p1_y*p2_z**3)%p
    s2 = (p2_y*p1_z**3)%p
    r = (s1 - s2)%p
    h = (u1 -u2)%p
    g = (h**3)%p
    v = (u1*h**2)%p
    p3_x = (r**2 + g - 2*v)%p
    p3_y = (r*(v-p3_x) - s1*g)%p
    p3_z = (p1_z*p2_z*h)%p
    
    p3_x = (p3_x*inverse(p3_z,p)**2)%p
    p3_y = (p3_y*inverse(p3_z,p)**3)%p
    return p3_x,p3_y

def modmul(a,b,p,p_not,r):
    #here values of n_not will actualy be precomputed and same everywhere
    t = (a*b) %r
    m=(t*p_not)%r
    u=(a*b+m*p)//r
    if(u>p):
        return u-p
    else:
        return u

def point_add_affine_montgomery(p1_x,p1_y,p2_x,p2_y,a,p):
    if p1_x == None:
        return p2_x,p2_y
    if p2_x == None:
        return p1_x,p1_y
    inv = inverse((p2_x-p1_x)%p,p)
    r=1<<5
    r_not = inverse(r,p)
    p_not = (r*r_not-1)//p
    
    y1_m = (p1_y * r) %p
    y2_m = (p2_y * r) %p
    x1_m = (p1_x * r) %p
    x2_m = (p2_x * r) %p
    inv_m = (inv * r) %p
    
    m = modmul((y2_m - y1_m)%p,inv_m,p,p_not,r)
    p3_x = (modmul(m,m,p,p_not,r)-x1_m-x2_m)%p
    p3_y = (-(y1_m + modmul(m,(p3_x-x1_m),p,p_not,r)))%p
    
    p3_x = modmul(p3_x,1,p,p_not,r)
    p3_y = modmul(p3_y,1,p,p_not,r)
    
    return (p3_x,p3_y)
    
def point_add_jacobian_montgomery(p1_x,p1_y,p2_x,p2_y,a,p):
    if p1_x == None:
        return p2_x,p2_y
    if p2_x == None:
        return p1_x,p1_y
    #here i define z=1, but for chained operations we should carry z between all operations
    r = 1<<5
    
    p1_z = 1
    p2_z = 1
    
    r_not = inverse(r,p)    
    p_not = (r*r_not-1)//p
    
    x1 = p1_x*r%p
    x2 = p2_x*r%p
    y1 = p1_y*r%p
    y2 = p2_y*r%p
    z1 = p1_z*r%p
    z2 = p2_z*r%p
    
    q = (p,p_not,r)

    z1_sq = modmul(z1,z1,*q)
    z2_sq = modmul(z2,z2,*q)
    z1_tr = modmul(z1_sq,z1,*q)
    z2_tr = modmul(z2_sq,z2,*q)

    u1 = modmul(x1,z2_sq,*q)
    u2 = modmul(x2,z1_sq,*q)
    s1 = modmul(y1,z2_tr,*q)
    s2 = modmul(y2,z1_tr,*q)

    r = (s1 - s2) %p
    h = (u1 - u2) %p
    
    h_sq = modmul(h,h,*q)
    g = modmul(h_sq,h,*q)
    v = modmul(u1,h_sq,*q)
    
    p3_x = (modmul(r,r,*q) + g - (v+v))%p
    p3_y = (modmul(r,(v-p3_x),*q) - modmul(s1,g,*q))%p
    p3_z = modmul(modmul(z1,z2,*q),h,*q)

    # u1 = (p1_x*p2_z**2)%p
    # u2 = (p2_x*p1_z**2)%p
    # s1 = (p1_y*p2_z**3)%p
    # s2 = (p2_y*p1_z**3)%p
    # r = (s1 - s2)%p
    # h = (u1 -u2)%p
    # g = (h**3)%p
    # v = (u1*h**2)%p
    # p3_x = (r**2 + g - 2*v)%p
    # p3_y = (r*(v-p3_x) - s1*g)%p
    # p3_z = (p1_z*p2_z*h)%p
    
    p3_x = modmul(p3_x, 1, *q)
    p3_y = modmul(p3_y, 1, *q)
    p3_z = modmul(p3_z, 1, *q)
    
    p3_x = (p3_x*inverse(p3_z**2,p))%p
    p3_y = (p3_y*inverse(p3_z**3,p))%p

    
    return p3_x,p3_y
    
    
def run_testbench():
    # p = 23               
    # a = 1                
    # b = 1                
    # g_coords = (3, 10)   
    # n = 28               
    # h = 1                
    
    # field = ec.SubGroup(p, g_coords, n, h)
    # custom_curve = ec.Curve(a, b, field)

    # print(f"Testing Curve: y^2 = x^3 + {a}x + {b} (mod {p})")

    # G = custom_curve.g

    # P1 = 2 * G
    # P2 = 27 * G
    # P_sum = P1 + P2
    
    p = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC7
    a = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDC4
    b = 0x00E8C2505DEDFC86DDC1BD0B2B6667F1DA34B82574761CB0E879BD081CFD0B6265EE3CB090F30D27614CB4574010DA90DD862EF9D4EBEE4761503190785A71C760
    q = 0x00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF27E69532F48D89116FF22B8D4E0560609B4B38ABFAD2B85DCACDB1411F10B275
    gx = 0x03
    gy = 0x7503CFE87A836AE3A61B8816E25450E6CE5E1C93ACF1ABC1778064FDCBEFA921DF1626BE4FD036E93D75E6A50E3A41E98028FE5FC235F5B889A589CB5215F2A4
    gost_512_paramA = Curve(
        'id-tc26-gost-3410-12-512-paramSetA', 
        p, a, b, q, gx, gy
    )
    
    G = gost_512_paramA.G
    
    P1 = (q-1) * G
    P2 = 1 * G

    P_sum = P1 + P2
    
    x,y = point_add(P1.x,P1.y,P2.x,P2.y,a,p)

    print(f"P1: ({P1.x},{P1.y})")
    print(f"P2: ({P2.x},{P2.y})")
    print(f"G:      ({G.x}, {G.y})")
    print(f"P1+P2:  ({P_sum.x}, {P_sum.y})")
    print(f"Manual:  ({x}, {y})")

    assert (P_sum.x == x and P_sum.y == y), "Error"
    
    for i in range(0,100):
        k = random.randint(0,22)
        if k==1:
            k=2
        P1 = (p)*G
        P2 = 1*G
        P_sum = P1 + P2
        try:
            x,y = point_add(P1.x,P1.y,P2.x,P2.y,a,p) 
        except:
            print("initial data {P1.x,P1.y,P2.x,P2.y}")
        assert (P_sum.x == x and P_sum.y == y), "Error " + f"P.x, P.y = {P_sum.x, P_sum.y}, func x,y = {x,y}\n" + f"initial data {P1.x,P1.y,P2.x,P2.y}"
    
    print("\n Success")
    


if __name__ == "__main__":
    run_testbench()